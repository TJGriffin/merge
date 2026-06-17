/**
* @author tj@tjgriffin.com
* @group Merge
* @description Service for #35: from a Contact merge candidate, merge the contacts' associated
* Accounts (the contacts themselves survive) instead of merging the contacts.
*
* The surviving Account is chosen by the keep-record rules (#32) applied to the associated Accounts,
* falling back to the lowest sorted Id when no rule yields a unique winner. The actual merge reuses
* the existing Account merge machinery by constructing a synthetic Account MergeCandidate and running
* it through MRG_Merge_SVC.processMergesFromBatch.
*/
public with sharing class MRG_AccountMerge_SVC {

	public static final String STATUS_ACCOUNTS_MERGED = 'Accounts Merged';

	/*******************************************************************************************************
	* @description evaluates the auto-merge-accounts rules against each candidate's records and sets
	* AutoMergeAccounts__c on candidates matched by a rule whose AutoMerge is true. Called at scan time
	* (does not DML; the caller upserts the candidates). Candidates whose object has no rules are left
	* untouched.
	* @param candidates the merge candidates (e.g. Contact candidates)
	* @param objectType the candidate object api name
	*/
	public static void flagAutoMergeAccounts(List<MergeCandidate__c> candidates, String objectType) {
		List<MRG_AutoMergeAccountsRule> rules = MRG_AutoMergeAccountsRule.getRules(objectType);
		if(rules.isEmpty() || candidates == null || candidates.isEmpty())
			return;
		// gather referenced fields and all candidate record ids
		Set<String> fields = new Set<String>{'Id'};
		Boolean anyAuto = false;
		for(MRG_AutoMergeAccountsRule rule:rules) {
			fields.addAll(rule.referencedFields());
			anyAuto = anyAuto || rule.autoMerge == true;
		}
		if(!anyAuto)
			return; // no auto rule could set the flag; manual action remains available
		Set<Id> recordIds = new Set<Id>();
		for(MergeCandidate__c c:candidates)
			recordIds.addAll(candidateRecordIds(c));
		if(recordIds.isEmpty())
			return;
		String soql = 'SELECT ' + String.join(new List<String>(fields), ',') + ' FROM ' + objectType + ' WHERE Id IN :recordIds';
		Map<Id, SObject> recordsById = new Map<Id, SObject>(Database.query(soql));
		for(MergeCandidate__c c:candidates) {
			List<SObject> recordGroup = new List<SObject>();
			for(Id rid:candidateRecordIds(c)) {
				if(recordsById.containsKey(rid))
					recordGroup.add(recordsById.get(rid));
			}
			if(recordGroup.size() < 2)
				continue;
			for(MRG_AutoMergeAccountsRule rule:rules) {
				if(rule.autoMerge == true && rule.matches(recordGroup)) {
					c.AutoMergeAccounts__c = true;
					break;
				}
			}
		}
	}

	/*******************************************************************************************************
	* @description the candidate's record ids (keep/merge/merge2)
	*/
	private static List<Id> candidateRecordIds(MergeCandidate__c c) {
		List<Id> ids = new List<Id>();
		if(String.isNotBlank(c.KeepRecordId__c)) ids.add((Id) c.KeepRecordId__c);
		if(String.isNotBlank(c.MergeRecordId__c)) ids.add((Id) c.MergeRecordId__c);
		return ids;
	}

	/*******************************************************************************************************
	* @description the distinct AccountIds referenced by a contact merge candidate's contacts
	* @param candidate the contact merge candidate
	* @return List<Id> account ids (order: keep contact's account first when present)
	*/
	public static List<Id> getAccountIds(MergeCandidate__c candidate) {
		List<Id> contactIds = new List<Id>();
		if(String.isNotBlank(candidate.KeepRecordId__c)) contactIds.add((Id) candidate.KeepRecordId__c);
		if(String.isNotBlank(candidate.MergeRecordId__c)) contactIds.add((Id) candidate.MergeRecordId__c);

		Map<Id, Id> accountByContact = new Map<Id, Id>();
		for(Contact c:[SELECT Id, AccountId FROM Contact WHERE Id IN :contactIds]) {
			if(c.AccountId != null)
				accountByContact.put(c.Id, c.AccountId);
		}
		// preserve contact order, de-duplicate accounts
		List<Id> accountIds = new List<Id>();
		Set<Id> seen = new Set<Id>();
		for(Id contactId:contactIds) {
			Id acctId = accountByContact.get(contactId);
			if(acctId != null && !seen.contains(acctId)) {
				accountIds.add(acctId);
				seen.add(acctId);
			}
		}
		return accountIds;
	}

	/*******************************************************************************************************
	* @description chooses the surviving Account id from a set of account ids: keep-record rules first,
	* then the lowest sorted id as a default
	* @param accountIds the candidate accounts
	* @return Id the surviving account id, or null when fewer than two distinct accounts
	*/
	public static Id selectKeepAccountId(List<Id> accountIds) {
		if(accountIds == null || accountIds.size() < 2)
			return null;
		List<MRG_KeepRecordRule> rules = MRG_KeepRecordRule.getRules('Account');
		if(!rules.isEmpty()) {
			Set<String> fields = new Set<String>{'Id'};
			for(MRG_KeepRecordRule rule:rules)
				fields.addAll(rule.referencedFields());
			Set<Id> ids = new Set<Id>(accountIds);
			List<SObject> accounts = Database.query(
				'SELECT ' + String.join(new List<String>(fields), ',') + ' FROM Account WHERE Id IN :ids');
			Id ruleKeep = MRG_KeepRecordRule.selectKeepId(rules, accounts);
			if(ruleKeep != null)
				return ruleKeep;
		}
		// default: lowest sorted id
		List<String> sorted = new List<String>();
		for(Id a:accountIds) sorted.add(String.valueOf(a));
		sorted.sort();
		return (Id) sorted[0];
	}

	/*******************************************************************************************************
	* @description builds an Account MergeCandidate from a list of account ids, with keepId first, so the
	* existing Account merge machinery can process it. Populates the required KeepName__c from the keep
	* Account's Name. Not inserted here.
	* @param accountIds the accounts (keepId chosen by selectKeepAccountId)
	* @param keepAccountId the surviving account id
	* @return MergeCandidate__c an Account candidate
	*/
	public static MergeCandidate__c buildAccountCandidate(List<Id> accountIds, Id keepAccountId) {
		List<Id> ordered = new List<Id>{ keepAccountId };
		for(Id a:accountIds) {
			if(a != keepAccountId)
				ordered.add(a);
		}
		Map<Id, Account> accountsById = new Map<Id, Account>([SELECT Id, Name FROM Account WHERE Id IN :accountIds]);
		Id mergeAccountId = ordered.size() > 1 ? ordered[1] : null;
		MergeCandidate__c accountCandidate = new MergeCandidate__c(
			KeepRecordId__c = ordered[0],
			KeepName__c = accountsById.containsKey(keepAccountId) ? accountsById.get(keepAccountId).Name : 'Account',
			MergeRecordId__c = mergeAccountId,
			MergeName__c = mergeAccountId != null && accountsById.containsKey(mergeAccountId) ? accountsById.get(mergeAccountId).Name : null,
			PairKey__c = String.valueOf(ordered[0]) + '-' + String.valueOf(mergeAccountId),
			Object__c = 'Account',
			Rule__c = 'Contact Account Merge',
			Status__c = 'New'
		);
		return accountCandidate;
	}

	/*******************************************************************************************************
	* @description merges the Accounts associated with a contact merge candidate's contacts. The contacts
	* are left unmerged; the candidate is marked STATUS_ACCOUNTS_MERGED. Returns the surviving account id,
	* or null when there is nothing to merge (fewer than two distinct accounts).
	* @param candidate the contact merge candidate
	* @return Id the surviving account id, or null
	*/
	public static Id mergeAccounts(MergeCandidate__c candidate) {
		List<Id> accountIds = getAccountIds(candidate);
		Id keepAccountId = selectKeepAccountId(accountIds);
		if(keepAccountId == null)
			return null;
		MergeCandidate__c accountCandidate = buildAccountCandidate(accountIds, keepAccountId);
		// upsert a real Account candidate so the merge is auditable and the existing machinery can
		// map/update it by Id, then reuse the full Account merge (preserve/complex/fallback/history).
		// upsert by PairKey is idempotent if the same account pair already exists (e.g. from a scan).
		upsert accountCandidate PairKey__c;
		MRG_Merge_SVC.processMergesFromBatch(new List<MergeCandidate__c>{ accountCandidate }, 'Account');
		// mark the originating contact candidate; contacts are intentionally not merged
		candidate.Status__c = STATUS_ACCOUNTS_MERGED;
		candidate.MergeProcessDate__c = Date.today();
		update candidate;
		return keepAccountId;
	}
}
