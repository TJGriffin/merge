/**
* @author tj@tjgriffin.com
* @group Merge
* @description integration test: a Complex preserve rule applied through the production merge path
*/
@isTest
private class MRG_ComplexMerge_TEST {

	// in-memory Complex MergeFieldSetting__mdt (Preserve + rule Complex) via JSON injection
	private static MergeFieldSetting__mdt complexSetting(String objectName, String fieldName, String tieBreakField, String tieBreakDir, List<MRG_KeepRecordRule.condition> conditions) {
		MergeFieldSetting__mdt mf = new MergeFieldSetting__mdt();
		Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(mf));
		m.put(MergeFieldSetting__mdt.Label.getDescribe().getName(), 'test'+fieldName);
		m.put(MergeFieldSetting__mdt.DeveloperName.getDescribe().getName(), 'test'+fieldName);
		m.put(MergeFieldSetting__mdt.Type__c.getDescribe().getName(), 'Preserve');
		m.put(MergeFieldSetting__mdt.Disable__c.getDescribe().getName(), false);
		m.put(MergeFieldSetting__mdt.PreservationRule__c.getDescribe().getName(), 'Complex');
		m.put(MergeFieldSetting__mdt.FilterLogic__c.getDescribe().getName(), '');
		m.put(MergeFieldSetting__mdt.Conditions__c.getDescribe().getName(), JSON.serialize(conditions));
		m.put(MergeFieldSetting__mdt.TieBreakDirection__c.getDescribe().getName(), tieBreakDir);
		m.put('Object__r', new Map<String, Object>{ 'attributes' => new Map<String, Object>{ 'type' => 'EntityDefinition' }, 'QualifiedAPIName' => objectName });
		m.put('Field__r', new Map<String, Object>{ 'attributes' => new Map<String, Object>{ 'type' => 'EntityParticle' }, 'QualifiedAPIName' => fieldName });
		m.put('TieBreakField__r', new Map<String, Object>{ 'attributes' => new Map<String, Object>{ 'type' => 'EntityParticle' }, 'QualifiedAPIName' => tieBreakField });
		return (MergeFieldSetting__mdt) JSON.deserialize(JSON.serialize(m), MergeFieldSetting__mdt.class);
	}

	private static MRG_KeepRecordRule.condition cond(String field, String op, String val) {
		return new MRG_KeepRecordRule.condition(field, op, val);
	}

	static testMethod void testComplexRulePreservesWinningValueThroughMerge() {
		// ticket example: preserve MailingStreet from the record where HasOptedOutOfEmail = true,
		// tie-broken by the latest Birthdate (DESC). Three records, two opted out.
		List<Contact> cons = MRG_TestFactory.contacts(3);
		Id keepId = cons[0].Id;
		Id mergeId = cons[1].Id;
		Id merge2Id = cons[2].Id;
		update new List<Contact>{
			// keep: not opted out, no street
			new Contact(Id=keepId, HasOptedOutOfEmail=false, MailingStreet=null, Birthdate=Date.newInstance(1970,1,1)),
			// merged A: opted out, older birthdate
			new Contact(Id=mergeId, HasOptedOutOfEmail=true, MailingStreet='OLD STREET', Birthdate=Date.newInstance(1980,1,1)),
			// merged B: opted out, newest birthdate -> tie-break DESC winner
			new Contact(Id=merge2Id, HasOptedOutOfEmail=true, MailingStreet='WIN STREET', Birthdate=Date.newInstance(2000,1,1))
		};

		MRG_Merge_SVC.mergeFields = new List<MergeFieldSetting__mdt>{
			complexSetting('Contact', 'MailingStreet', 'Birthdate', 'DESC',
				new List<MRG_KeepRecordRule.condition>{ cond('HasOptedOutOfEmail','equals','true') })
		};
		MRG_Merge_SVC.previewFields = new List<PreviewFields__mdt>();

		List<MergeCandidate__c> mcs = MRG_TestFactory.mergeCandidatePairs(keepId, new List<Id>{ mergeId, merge2Id }, 'Contact');

		Test.startTest();
		MRG_TestFactory.runMerge(mcs, 'Contact');
		Test.stopTest();

		// the kept record should carry the winning record's street (the opted-out, newest-birthdate one)
		system.assertEquals('WIN STREET', (String) MRG_TestFactory.keptValue(keepId, 'Contact', 'MailingStreet'),
			'Complex rule should preserve the value from the condition-matching, tie-break-winning record');

		// and a field-history entry should record the change
		Map<String, MergeFieldHistory__c> history = MRG_TestFactory.historyByField(keepId);
		system.assert(history.containsKey('mailingstreet'), 'complex preserve change should be tracked');
		system.assertEquals('WIN STREET', history.get('mailingstreet').KeptValue__c);
	}

	static testMethod void testComplexRuleNoConditionMatchLeavesFieldUnchanged() {
		List<Contact> cons = MRG_TestFactory.contacts(2);
		Id keepId = cons[0].Id;
		Id mergeId = cons[1].Id;
		update new List<Contact>{
			new Contact(Id=keepId, HasOptedOutOfEmail=false, MailingStreet='KEEP'),
			new Contact(Id=mergeId, HasOptedOutOfEmail=false, MailingStreet='LOSE')
		};
		MRG_Merge_SVC.mergeFields = new List<MergeFieldSetting__mdt>{
			complexSetting('Contact', 'MailingStreet', 'Birthdate', 'DESC',
				new List<MRG_KeepRecordRule.condition>{ cond('HasOptedOutOfEmail','equals','true') })
		};
		MRG_Merge_SVC.previewFields = new List<PreviewFields__mdt>();

		MergeCandidate__c mc = MRG_TestFactory.mergeCandidate(keepId, mergeId, 'Contact');

		Test.startTest();
		MRG_TestFactory.runMerge(new List<MergeCandidate__c>{ mc }, 'Contact');
		Test.stopTest();

		// no record matches the condition -> complex rule does not change the kept value
		system.assertEquals('KEEP', (String) MRG_TestFactory.keptValue(keepId, 'Contact', 'MailingStreet'),
			'no condition match -> kept value unchanged by the complex rule');
	}
}
