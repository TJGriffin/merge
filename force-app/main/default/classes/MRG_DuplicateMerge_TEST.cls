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
            PairKey__c = String.valueOf(cons[0].Id) + '-' + String.valueOf(cons[1].Id),
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
        List<MRG_DuplicateMerge_CTRL.keepGroup> groups = MRG_DuplicateMerge_CTRL.getKeepGroups('Contact','test',100,0);
        system.assert(!groups.isEmpty(), 'a keep group should be returned');
        List<MRG_DuplicateMerge_CTRL.mergeGroup> pairs = groups[0].pairs;
        String mergeGroupJSON = JSON.serialize(pairs[0]);
        List<SObject> objs = MRG_DuplicateMerge_CTRL.getSObjectsFromMergeGroup(mergeGroupJSON);
        List<MergeCandidate__c> candidates = MRG_DuplicateMerge_CTRL.getMergeCandidateFromMergeGroup(pairs);
        String response = MRG_DuplicateMerge_CTRL.removeRecord(candidates[0].Id);
        test.startTest();
        response = MRG_DuplicateMerge_CTRL.mergeRecord(candidates[0].Id);
        test.stopTest();
    }

    static testMethod void testGetRulesIncludesCandidateRules(){
        // the candidate's Rule__c ('test') maps to no Salesforce duplicate rule (the external-provider
        // case); it must still appear in the merge-review rule filter
        List<MRG_Duplicate_SVC.dupeRule> rules = MRG_DuplicateMerge_CTRL.getRules('Contact');
        Boolean found = false;
        for(MRG_Duplicate_SVC.dupeRule rule:rules){
            if(rule.ruleName == 'test')
                found = true;
        }
        system.assert(found, 'a candidate Rule__c value with no Salesforce duplicate rule should appear in the filter');
    }

    static testMethod void testMergeGroupExposesConfidenceAndSource(){
        MergeCandidate__c mc = [SELECT Id FROM MergeCandidate__c LIMIT 1];
        mc.ConfidenceScore__c = 95.50;
        mc.Source__c = 'External';
        update mc;
        List<MRG_DuplicateMerge_CTRL.keepGroup> groups = MRG_DuplicateMerge_CTRL.getKeepGroups('Contact','test',100,0);
        system.assertEquals(1, groups.size(), 'one keep group should be returned');
        system.assertEquals(1, groups[0].pairs.size(), 'the keep group should have one pair');
        system.assertEquals(95.50, groups[0].pairs[0].confidenceScore, 'confidence score should flow through to the pair wrapper');
        system.assertEquals('External', groups[0].pairs[0].source, 'source should flow through to the pair wrapper');
    }

    static testMethod void testKeepGroupsOrderedByConfidenceDesc(){
        // a keep with two duplicate pairs: the pairs must group under the keep, ordered confidence desc
        List<Contact> cons = MRG_TestFactory.contacts(3);
        Id keepId = cons[0].Id;
        List<MergeCandidate__c> pairs = MRG_TestFactory.mergeCandidatePairs(keepId, new List<Id>{ cons[1].Id, cons[2].Id }, 'Contact');
        pairs[0].ConfidenceScore__c = 10.00;
        pairs[1].ConfidenceScore__c = 90.00;
        update pairs;
        MRG_DuplicateMerge_CTRL.keepGroup grp;
        for(MRG_DuplicateMerge_CTRL.keepGroup g:MRG_DuplicateMerge_CTRL.getKeepGroups('Contact','test',100,0)){
            if(g.keepId == String.valueOf(keepId))
                grp = g;
        }
        system.assertNotEquals(null, grp, 'the keep group should be present');
        system.assertEquals(2, grp.pairs.size(), 'both pairs should group under the one keep');
        system.assertEquals(90.00, grp.pairs[0].confidenceScore, 'highest confidence pair should sort first');
        system.assertEquals(10.00, grp.pairs[1].confidenceScore, 'lower confidence pair should sort second');
    }

    static testMethod void testBatch(){

        test.startTest();
        database.executeBatch(new MRG_DuplicateMerge_BATCH());

        test.stopTest();
    }
    static testMethod void testBatchRestoresTriggerState(){
        // pre-batch state: Account trigger already disabled, Contact trigger enabled
        MergeControlSettings__c settings = MRG_Merge_SVC.getSettings();
        settings.DisableAccountTrigger__c = true;
        settings.DisableContactTrigger__c = false;
        upsert settings;

        test.startTest();
        database.executeBatch(new MRG_DuplicateMerge_BATCH(new Set<String>{'Contact'}));
        test.stopTest();

        // after the chain finishes the original state must be restored, not left disabled
        MergeControlSettings__c restored = MRG_Merge_SVC.getSettings();
        system.assertEquals(true, restored.DisableAccountTrigger__c, 'Account trigger state should be restored to its pre-batch value');
        system.assertEquals(false, restored.DisableContactTrigger__c, 'Contact trigger state should be restored to its pre-batch value');
    }
    static testMethod void testBatch2(){

        test.startTest();
        database.executeBatch(new MRG_DuplicateMerge_BATCH(new Set<String>{'Contact'}));

        test.stopTest();
    }

	static testMethod void testMergeCandidate(){
		MRG_MergeCandidate mergeCandidate1 = new MRG_MergeCandidate();
		MRG_Merge_TEST.createMergeFields();
		MergeCandidate__c can = [SELECT Id FROM MergeCandidate__c LIMIT 1];
		test.startTest();
		MRG_MergeCandidate mergeCandidate = MRG_MergeCandidate_SVC.getMergeCandidate(can.Id);
		test.stopTest();

	}
	static testMethod void testMergeCandidate2(){
		MRG_Merge_TEST.createMergeFields();
        MergeCandidate__c can = [
            SELECT Id,
            AutoMerge__c,
            Data__c,
            KeepName__c,
            KeepRecordId__c,
            Merge2Name__c,
            Merge2RecordId__c,
            MergeName__c,
            MergeRecordId__c,
            NotADuplicate__c,
            Object__c,
            Override__c,
            Rule__c,
            Status__c
            FROM MergeCandidate__c
            LIMIT 1
        ];
		can.Status__c = 'Processed';
		MRG_Merge_SVC.MergeHistoryResult mrgResult = MRG_Merge_SVC.getMergeHistoryResult(new List<MergeCandidate__c>{can},'Contact');
		can.Data__c = JSON.serialize(mrgResult);
		update can;
		test.startTest();
		MRG_MergeCandidate mergeCandidate = MRG_MergeCandidate_SVC.getMergeCandidate(can.Id);
		test.stopTest();

	}
}
