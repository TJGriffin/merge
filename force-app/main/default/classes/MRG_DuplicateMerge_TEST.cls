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
        Integer count = MRG_DuplicateMerge_CTRL.getCount(new MRG_Duplicate_SVC.candidateFilter('Contact','test'));
        List<MRG_DuplicateMerge_CTRL.keepGroup> groups = MRG_DuplicateMerge_CTRL.getKeepGroups(new MRG_Duplicate_SVC.candidateFilter('Contact','test'),100,0);
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
        List<MRG_DuplicateMerge_CTRL.keepGroup> groups = MRG_DuplicateMerge_CTRL.getKeepGroups(new MRG_Duplicate_SVC.candidateFilter('Contact','test'),100,0);
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
        for(MRG_DuplicateMerge_CTRL.keepGroup g:MRG_DuplicateMerge_CTRL.getKeepGroups(new MRG_Duplicate_SVC.candidateFilter('Contact','test'),100,0)){
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

	static testMethod void testStatusOptions(){
		List<Map<String,String>> opts = MRG_DuplicateMerge_CTRL.getStatusOptions();
		system.assertEquals(3, opts.size(), 'three status options should be offered');
	}

	static testMethod void testGridFieldOptions(){
		MRG_DuplicateMerge_CTRL.gridFieldOptions opts = MRG_DuplicateMerge_CTRL.getGridFieldOptions('Contact');
		system.assertEquals('Id', opts.leadFields[0].name, 'Id should be the first lead field');
		Set<String> trailNames = new Set<String>();
		for(MRG_DuplicateMerge_CTRL.gridFieldOption o:opts.trailFields)
			trailNames.add(o.name);
		system.assert(trailNames.contains('CreatedDate'), 'CreatedDate should be a trailing field');
		system.assert(trailNames.contains('LastModifiedDate'), 'LastModifiedDate should be a trailing field');
		system.assert(!opts.fields.isEmpty(), 'selectable fields should be returned');
		Integer defaultSelected = 0;
		for(MRG_DuplicateMerge_CTRL.gridFieldOption o:opts.fields)
			if(o.selected == true) defaultSelected++;
		system.assert(defaultSelected > 0, 'with no saved config the first fields should be selected by default');
	}

	static testMethod void testGridFieldConfigSaveLoad(){
		MRG_DuplicateMerge_CTRL.saveGridFieldConfig('Contact', new List<String>{'Email'});
		MRG_DuplicateMerge_CTRL.gridFieldOptions opts = MRG_DuplicateMerge_CTRL.getGridFieldOptions('Contact');
		Integer selectedCount = 0;
		Boolean emailSelected = false;
		for(MRG_DuplicateMerge_CTRL.gridFieldOption o:opts.fields){
			if(o.selected == true){
				selectedCount++;
				if(o.name == 'Email') emailSelected = true;
			}
		}
		system.assertEquals(1, selectedCount, 'only the saved field should be selected');
		system.assert(emailSelected, 'the saved Email field should be selected');
		// upsert by external id: saving again updates the same record rather than erroring
		MRG_DuplicateMerge_CTRL.saveGridFieldConfig('Contact', new List<String>{'Email','Phone'});
		system.assertEquals(1, [SELECT COUNT() FROM MergeGridConfig__c WHERE ObjectType__c='Contact'], 'one config record per object type');
	}

	static testMethod void testGridData(){
		MRG_Merge_TEST.createMergeFields();
		MRG_Duplicate_SVC.candidateFilter f = new MRG_Duplicate_SVC.candidateFilter('Contact','test');
		test.startTest();
		MRG_DuplicateMerge_CTRL.gridResponse resp = MRG_DuplicateMerge_CTRL.getGridData(
			f, new List<String>{'Email','CreatedDate','LastModifiedDate'}, 50, 1);
		test.stopTest();
		system.assert(!resp.columns.isEmpty(), 'columns should be returned');
		system.assertEquals('Id', resp.columns[0].name, 'Id should be the first column');
		system.assert(!resp.groups.isEmpty(), 'at least one keep group should be returned');
		Set<String> rowTypes = new Set<String>();
		for(MRG_DuplicateMerge_CTRL.gridRow r:resp.groups[0].rows)
			rowTypes.add(r.rowType);
		system.assert(rowTypes.contains('keep'), 'a keep row should be present');
		system.assert(rowTypes.contains('duplicate'), 'a duplicate row should be present');
		system.assert(rowTypes.contains('result'), 'a simulated result row should be present');
	}

	static testMethod void testGridDataPageSizeClamped(){
		MRG_Duplicate_SVC.candidateFilter f = new MRG_Duplicate_SVC.candidateFilter('Contact','test');
		// below-min and above-max page sizes must not throw and still return the page
		MRG_DuplicateMerge_CTRL.gridResponse small = MRG_DuplicateMerge_CTRL.getGridData(f, new List<String>{'Email'}, 1, 1);
		MRG_DuplicateMerge_CTRL.gridResponse big = MRG_DuplicateMerge_CTRL.getGridData(f, new List<String>{'Email'}, 9999, 1);
		system.assert(!small.groups.isEmpty(), 'a below-min page size should clamp to 10 and still return data');
		system.assert(!big.groups.isEmpty(), 'an above-max page size should clamp to 200 and still return data');
	}

	static testMethod void testCountFilters(){
		MergeCandidate__c mc = [SELECT Id FROM MergeCandidate__c LIMIT 1];
		mc.ConfidenceScore__c = 50;
		update mc;

		MRG_Duplicate_SVC.candidateFilter high = new MRG_Duplicate_SVC.candidateFilter('Contact','test');
		high.confidenceMin = 90;
		system.assertEquals(0, MRG_DuplicateMerge_CTRL.getCount(high), 'a min confidence above the candidate score should exclude it');

		MRG_Duplicate_SVC.candidateFilter low = new MRG_Duplicate_SVC.candidateFilter('Contact','test');
		low.confidenceMin = 10;
		system.assert(MRG_DuplicateMerge_CTRL.getCount(low) >= 1, 'a min confidence below the score should include it');

		MRG_Duplicate_SVC.candidateFilter notAuto = new MRG_Duplicate_SVC.candidateFilter('Contact','test');
		notAuto.autoMerge = false;
		system.assertEquals(0, MRG_DuplicateMerge_CTRL.getCount(notAuto), 'the auto-merge candidate should be excluded when filtering autoMerge=false');

		MRG_Duplicate_SVC.candidateFilter processed = new MRG_Duplicate_SVC.candidateFilter('Contact','test');
		processed.statuses = new List<String>{'Processed'};
		system.assertEquals(0, MRG_DuplicateMerge_CTRL.getCount(processed), 'a New candidate should be excluded when filtering status=Processed');
	}

	static testMethod void testBulkRemove(){
		Id mcId = [SELECT Id FROM MergeCandidate__c LIMIT 1].Id;
		test.startTest();
		String removeResp = MRG_DuplicateMerge_CTRL.removeRecords(new List<Id>{mcId});
		test.stopTest();
		system.assert(removeResp.contains('1'), 'one record should be removed');
		MergeCandidate__c rec = [SELECT NotADuplicate__c FROM MergeCandidate__c WHERE Id=:mcId];
		system.assertEquals(true, rec.NotADuplicate__c, 'the candidate should be marked not a duplicate');
		// empty selections are guarded
		system.assertEquals('No records selected', MRG_DuplicateMerge_CTRL.mergeRecords(new List<Id>()), 'empty merge selection should be guarded');
		system.assertEquals('No records selected', MRG_DuplicateMerge_CTRL.mergeAccountsBulk(new List<Id>()), 'empty account-merge selection should be guarded');
	}

	static testMethod void testBulkMerge(){
		MRG_Merge_TEST.createMergeFields();
		Id mcId = [SELECT Id FROM MergeCandidate__c LIMIT 1].Id;
		test.startTest();
		String resp = MRG_DuplicateMerge_CTRL.mergeRecords(new List<Id>{mcId});
		test.stopTest();
		system.assert(resp.contains('merged'), 'the bulk merge should report a merge');
	}
}
