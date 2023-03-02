@isTest
private class MRG_DuplicateMerge_TEST {
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

        MergeCandidate__c mc = new MergeCandidate__c(
            KeepRecordId__c = cons[0].Id,
            KeepName__c = 'Test',
            MergeRecordId__c = cons[1].Id,
            MergeName__c = 'Test 2',
            Object__c = 'Contact',
            Rule__c = 'test',
            Status__c = 'New',
            AutoMerge__c = true
        );
        insert mc;

		MRG_MergeCandidate.fieldOverride fldOr = new MRG_MergeCandidate.fieldOverride();
		fldOr.fieldName = 'MailingPostalCode';
		fldOr.fieldValue = '78754';
		fldOr.fieldType = 'STRING';
		fldOr.keepId = cons[0].Id;

		mc.Override__c = JSON.serialize(new List<MRG_MergeCandidate.fieldOverride>{fldOr});
		update mc;
	}
    static testMethod void testCTLR() {
        Integer count = MRG_DuplicateMerge_CTRL.getCount('Contact','test');
        List<MRG_DuplicateMerge_CTRL.mergeGroup> groups = MRG_DuplicateMerge_CTRL.getMergeGroups('Contact','test',100,0);
        String mergeGroupJSON = JSON.serialize(groups[0]);
        List<SObject> objs = MRG_DuplicateMerge_CTRL.getSObjectsFromMergeGroup(mergeGroupJSON);
        List<MergeCandidate__c> candidates = MRG_DuplicateMerge_CTRL.getMergeCandidateFromMergeGroup(groups);
        String response = MRG_DuplicateMerge_CTRL.removeRecord(candidates[0].Id);
        test.startTest();
        response = MRG_DuplicateMerge_CTRL.mergeRecord(candidates[0].Id);
        test.stopTest();
    }

    static testMethod void testBatch(){

        test.startTest();
        database.executeBatch(new MRG_DuplicateMerge_BATCH());

        test.stopTest();
    }
    static testMethod void testBatch2(){

        test.startTest();
        database.executeBatch(new MRG_DuplicateMerge_BATCH(new Set<String>{'Contact'}));

        test.stopTest();
    }
}
