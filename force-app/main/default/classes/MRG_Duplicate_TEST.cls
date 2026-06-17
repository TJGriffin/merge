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

	static testMethod void testBuildPairsExplodesGroupIntoPairs() {
		List<String> ids = new List<String>();
		for(Contact c:[SELECT Id FROM Contact]) ids.add(String.valueOf(c.Id));
		for(Account a:[SELECT Id FROM Account]) ids.add(String.valueOf(a.Id));
		List<String> ordered = new List<String>{ ids[0], ids[1], ids[2] };
		Map<String,String> names = new Map<String,String>{ ids[0] => 'Keep', ids[1] => 'M1', ids[2] => 'M2' };
		List<MergeCandidate__c> pairs = MRG_Duplicate_SVC.buildPairs(ordered, names, 'Contact', 'rx');
		system.assertEquals(2, pairs.size(), 'a 3-record group yields two (keep, merge) pairs');
		system.assertEquals(ids[0], pairs[0].KeepRecordId__c, 'all pairs share the keep');
		system.assertEquals(ids[0], pairs[1].KeepRecordId__c);
		system.assertEquals(ids[0] + '-' + ids[1], pairs[0].PairKey__c, 'pair key is keep-merge');
		system.assertEquals('Keep', pairs[0].KeepName__c);
		system.assert(MRG_Duplicate_SVC.buildPairs(new List<String>{ ids[0] }, names, 'Contact', 'rx').isEmpty(),
			'a single id yields no pairs');
	}

	static testMethod void testSelectKeepIdByRulesNoRulesReturnsNull() {
		List<Contact> cons = [SELECT Id FROM Contact];
		List<String> ids = new List<String>{ cons[0].Id, cons[1].Id };
		// no keep-record rules configured
		MRG_KeepRecordRule.keepRecordRules = new List<MRG_KeepRecordRule>();
		system.assertEquals(null, MRG_Duplicate_SVC.selectKeepIdByRules(ids, 'Contact'),
			'no rules -> null so caller keeps the sorted-id default');
	}

	static testMethod void testSelectKeepIdByRulesUniqueMatch() {
		// setup contacts: one in CA, one in TX
		List<Contact> cons = [SELECT Id, MailingState FROM Contact ORDER BY MailingState];
		Id caId = cons[0].MailingState == 'CA' ? cons[0].Id : cons[1].Id;
		List<String> ids = new List<String>{ cons[0].Id, cons[1].Id };

		MRG_KeepRecordRule rule = new MRG_KeepRecordRule();
		rule.objectName = 'Contact';
		rule.order = 1;
		rule.conditions = new List<MRG_KeepRecordRule.condition>{
			new MRG_KeepRecordRule.condition('MailingState','equals','CA')
		};
		MRG_KeepRecordRule.keepRecordRules = new List<MRG_KeepRecordRule>{ rule };

		system.assertEquals(caId, MRG_Duplicate_SVC.selectKeepIdByRules(ids, 'Contact'),
			'the CA record should be selected by the keep rule');
	}

	static testMethod void testSelectKeepIdByRulesNoUniqueMatchReturnsNull() {
		List<Contact> cons = [SELECT Id FROM Contact];
		List<String> ids = new List<String>{ cons[0].Id, cons[1].Id };
		// rule matches a state neither contact has -> no match -> null
		MRG_KeepRecordRule rule = new MRG_KeepRecordRule();
		rule.objectName = 'Contact';
		rule.order = 1;
		rule.conditions = new List<MRG_KeepRecordRule.condition>{
			new MRG_KeepRecordRule.condition('MailingState','equals','ZZ')
		};
		MRG_KeepRecordRule.keepRecordRules = new List<MRG_KeepRecordRule>{ rule };
		system.assertEquals(null, MRG_Duplicate_SVC.selectKeepIdByRules(ids, 'Contact'));
	}

}
