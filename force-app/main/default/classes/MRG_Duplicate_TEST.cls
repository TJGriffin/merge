@isTest
private class MRG_Duplicate_TEST {
	@testSetup static void setup() {
		List<Account> accs = new List<Account>();
		accs.add(
			new Account(
				Name='test1'
			)
		);
		accs.add(
			new Account(
				Name='test2'
			)
		);
		insert accs;
		List<Contact> cons = new List<Contact>();
		cons.add(
			new Contact(
			FirstName='Test',
			LastName='Test',
			Email='test@test.com',
			MailingCity='Austin',
			MailingState='TX',
			MailingPostalCode='78751',
			Birthdate=Date.Today().addDays(-1200)
			)
		);	
		cons.add(new Contact(
			FirstName='Test1',
			LastName='Test1',
			Email='tes1t@test.com',
			MailingStreet='123 Main Street',
			MailingState='CA',
			MailingPostalCode='78754',
			HasOptedOutOfEmail=true,
			Birthdate=Date.Today().addDays(-500)
			)
		);	

		insert cons;
	}
    static testMethod void testService() {
		String soqlQuery = MRG_Duplicate_SVC.getMergeCandidateFieldSOQL();
		String whereClause =  MRG_Duplicate_SVC.getWhereClause();
		whereClause = MRG_Duplicate_SVC.getWhereClause('Contact','test');
		Boolean isDisabled = MRG_Duplicate_SVC.getTriggerDisabled();
		List<MRG_Duplicate_SVC.dupeRule> rules = MRG_Duplicate_SVC.getActiveDuplicateRules();
		rules = MRG_Duplicate_SVC.getActiveDuplicateRules('Contact');
		soqlQuery = MRG_Duplicate_SVC.getScanSOQLQuery('Contact');
		soqlQuery = MRG_Duplicate_SVC.getMergeSOQLQuery('Contact');
		soqlQuery = MRG_Duplicate_SVC.getFieldSOQLQuery('Contact');

		Map<Id,SObject> recordMap  = new Map<Id,SObject>();
		for(SObject con:database.query(MRG_Duplicate_SVC.getScanSOQLQuery('Contact'))){
			recordMap.put((Id) con.get('Id'),con);
		}
		List<MergeCandidate__c> candidates = MRG_Duplicate_SVC.processRecords(recordMap,'Contact');

		Boolean duplicateRulesAreActive = MRG_Duplicate_SVC.duplicateRulesAreActive(recordMap.values());

		Map<Id,Set<Id>> mergeKeyMap = MRG_Duplicate_SVC.getMergeKeyMap(candidates);

		MergeCandidate__c mc = new MergeCandidate__c(KeepRecordId__c=recordMap.values()[0].Id,MergeRecordId__c=recordMap.values()[1].Id);
		mergeKeyMap = MRG_Duplicate_SVC.getMergeKeyMap(mc);

    }

}
