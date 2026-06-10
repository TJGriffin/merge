/**
* @author tj@tjgriffin.com
* @group Merge
* @description batch (#35): processes merge candidates flagged AutoMergeAccounts__c by merging the
* contacts' associated Accounts (the contacts are kept) instead of merging the contacts.
*/
public with sharing class MRG_AccountMerge_BATCH implements Database.Batchable<sObject>, Schedulable {

	/*******************************************************************************************************
	* @description batch start: New, auto-merge-accounts-flagged, not-a-duplicate candidates
	*/
	public Database.QueryLocator start(Database.BatchableContext BC) {
		String soqlQuery = MRG_Duplicate_SVC.getMergeCandidateFieldSOQL();
		soqlQuery += ' WHERE Status__c=\'New\' AND AutoMergeAccounts__c = true AND NotADuplicate__c = false';
		return Database.getQueryLocator(soqlQuery);
	}

	/*******************************************************************************************************
	* @description batch execute: merge the accounts behind each flagged candidate
	*/
	public void execute(Database.BatchableContext BC, List<sObject> scope) {
		for(MergeCandidate__c candidate:(List<MergeCandidate__c>) scope) {
			MRG_AccountMerge_SVC.mergeAccounts(candidate);
		}
	}

	public void finish(Database.BatchableContext BC) {}

	/*******************************************************************************************************
	* @description Schedulable execute
	*/
	public void execute(SchedulableContext SC) {
		Database.executeBatch(this, 1);
	}
}
