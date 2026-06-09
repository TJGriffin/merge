/**
* @author tj@tjgriffin.com
* @group Merge
* @description integration test: Fallback rules applied through the production merge path
*/
@isTest
private class MRG_FallbackMerge_TEST {

	private static MRG_KeepRecordRule.condition cond(String field, String op, String val) {
		return new MRG_KeepRecordRule.condition(field, op, val);
	}

	static testMethod void testFallbackRoutesLostEmailToTargetField() {
		// ticket spirit: keep one contact, but route the lost record's Email into the kept record's
		// Description (an otherwise-empty target). Complex selection: from the opted-out record.
		List<Contact> cons = MRG_TestFactory.contacts(2);
		Id keepId = cons[0].Id;
		Id mergeId = cons[1].Id;
		update new List<Contact>{
			new Contact(Id=keepId, Email='keep@test.com', Description=null, HasOptedOutOfEmail=false),
			new Contact(Id=mergeId, Email='lost@test.com', HasOptedOutOfEmail=true)
		};

		MRG_Merge_SVC.mergeFields = new List<MergeFieldSetting__mdt>();
		MRG_Merge_SVC.previewFields = new List<PreviewFields__mdt>();

		MRG_FallbackRule rule = new MRG_FallbackRule();
		rule.objectName = 'Contact';
		rule.selectionType = 'complex';
		rule.filterLogic = '1';
		rule.conditions = new List<MRG_KeepRecordRule.condition>{ cond('HasOptedOutOfEmail','equals','true') };
		rule.fieldPairs = new List<MRG_FallbackRule.fieldPair>{ new MRG_FallbackRule.fieldPair('Email','Description') };
		MRG_FallbackRule.fallbackRules = new List<MRG_FallbackRule>{ rule };

		MergeCandidate__c mc = MRG_TestFactory.mergeCandidate(keepId, mergeId, 'Contact');

		Test.startTest();
		MRG_TestFactory.runMerge(new List<MergeCandidate__c>{ mc }, 'Contact');
		Test.stopTest();

		system.assertEquals('lost@test.com', (String) MRG_TestFactory.keptValue(keepId, 'Contact', 'Description'),
			'fallback should route the lost (opted-out) record email into the empty Description target');
		// kept email itself is untouched by the fallback
		system.assertEquals('keep@test.com', (String) MRG_TestFactory.keptValue(keepId, 'Contact', 'Email'),
			'fallback writes only the target field, not the source field on keep');

		// tracking-aware history: source field recorded with the target it was routed to
		List<MergeFieldHistory__c> history = [
			SELECT MergeValueType__c, TargetField__c, KeptValue__c FROM MergeFieldHistory__c WHERE KeptRecordId__c=:keepId
		];
		Boolean found = false;
		for(MergeFieldHistory__c h:history) {
			if(h.MergeValueType__c == 'Email' && h.TargetField__c == 'Description') {
				found = true;
				system.assertEquals('lost@test.com', h.KeptValue__c);
			}
		}
		system.assert(found, 'history should record Email routed to Description');
	}

	static testMethod void testFallbackSkipsWhenTargetNotEmpty() {
		List<Contact> cons = MRG_TestFactory.contacts(2);
		Id keepId = cons[0].Id;
		Id mergeId = cons[1].Id;
		update new List<Contact>{
			new Contact(Id=keepId, Description='already set', HasOptedOutOfEmail=false),
			new Contact(Id=mergeId, Email='lost@test.com', HasOptedOutOfEmail=true)
		};
		MRG_Merge_SVC.mergeFields = new List<MergeFieldSetting__mdt>();
		MRG_Merge_SVC.previewFields = new List<PreviewFields__mdt>();

		MRG_FallbackRule rule = new MRG_FallbackRule();
		rule.objectName = 'Contact';
		rule.selectionType = 'complex';
		rule.filterLogic = '1';
		rule.conditions = new List<MRG_KeepRecordRule.condition>{ cond('HasOptedOutOfEmail','equals','true') };
		rule.fieldPairs = new List<MRG_FallbackRule.fieldPair>{ new MRG_FallbackRule.fieldPair('Email','Description') };
		MRG_FallbackRule.fallbackRules = new List<MRG_FallbackRule>{ rule };

		MergeCandidate__c mc = MRG_TestFactory.mergeCandidate(keepId, mergeId, 'Contact');

		Test.startTest();
		MRG_TestFactory.runMerge(new List<MergeCandidate__c>{ mc }, 'Contact');
		Test.stopTest();

		system.assertEquals('already set', (String) MRG_TestFactory.keptValue(keepId, 'Contact', 'Description'),
			'fallback must not overwrite a populated target');
	}
}
