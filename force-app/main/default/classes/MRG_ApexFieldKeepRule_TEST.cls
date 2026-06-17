/**
* @author tj@tjgriffin.com
* @group Merge
* @description tests for the Apex Defined field-keep rule: the resolver runs after the built-in rules,
* its value is applied to the kept record and tracked, a bad class name is skipped (not fatal), and
* the shipped example resolver behaves as documented.
*/
@isTest
private class MRG_ApexFieldKeepRule_TEST {

	// build a Preserve MergeFieldSetting whose rule delegates to an Apex resolver class
	private static MergeFieldSetting__mdt apexSetting(String objectName, String fieldName, String apexClass) {
		MergeFieldSetting__mdt setting = new MergeFieldSetting__mdt(
			Label = fieldName,
			Type__c = 'Preserve',
			PreservationRule__c = 'Apex Defined',
			ApexClass__c = apexClass,
			Disable__c = false
		);
		Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(setting));
		m.put('Field__r', new Map<String, Object>{ 'attributes' => new Map<String, Object>{ 'type' => 'EntityParticle' }, 'QualifiedAPIName' => fieldName });
		m.put('Object__r', new Map<String, Object>{ 'attributes' => new Map<String, Object>{ 'type' => 'EntityDefinition' }, 'QualifiedAPIName' => objectName });
		return (MergeFieldSetting__mdt) JSON.deserialize(JSON.serialize(m), MergeFieldSetting__mdt.class);
	}

	static testMethod void testApexDefinedRuleKeepsResolvedValue() {
		List<Contact> cons = MRG_TestFactory.contacts(2);
		Id keepId = cons[0].Id;
		Id mergeId = cons[1].Id;
		update new List<Contact>{
			new Contact(Id=keepId, MailingStreet='short'),
			new Contact(Id=mergeId, MailingStreet='a much longer street value')
		};
		MRG_Merge_SVC.mergeFields = new List<MergeFieldSetting__mdt>{
			apexSetting('Contact', 'MailingStreet', 'MRG_SampleFieldKeepRule')
		};
		MRG_Merge_SVC.previewFields = new List<PreviewFields__mdt>();
		MergeCandidate__c mc = MRG_TestFactory.mergeCandidate(keepId, mergeId, 'Contact');

		Test.startTest();
		MRG_TestFactory.runMerge(new List<MergeCandidate__c>{ mc }, 'Contact');
		Test.stopTest();

		system.assertEquals('a much longer street value', (String) MRG_TestFactory.keptValue(keepId, 'Contact', 'MailingStreet'),
			'the Apex Defined resolver should keep the longest value');
		Map<String, MergeFieldHistory__c> history = MRG_TestFactory.historyByField(keepId);
		system.assert(history.containsKey('mailingstreet'), 'the Apex-decided change should be tracked in history');
	}

	static testMethod void testApexDefinedRuleInvalidClassIsSkipped() {
		List<Contact> cons = MRG_TestFactory.contacts(2);
		Id keepId = cons[0].Id;
		Id mergeId = cons[1].Id;
		update new List<Contact>{
			new Contact(Id=keepId, MailingState='TX'),
			new Contact(Id=mergeId, MailingState='CA')
		};
		MRG_Merge_SVC.mergeFields = new List<MergeFieldSetting__mdt>{
			apexSetting('Contact', 'MailingState', 'Not_A_Real_Class_XYZ')
		};
		MRG_Merge_SVC.previewFields = new List<PreviewFields__mdt>();
		MergeCandidate__c mc = MRG_TestFactory.mergeCandidate(keepId, mergeId, 'Contact');

		Test.startTest();
		// a missing/invalid resolver class must be skipped, not throw
		MRG_TestFactory.runMerge(new List<MergeCandidate__c>{ mc }, 'Contact');
		Test.stopTest();

		system.assertEquals('TX', (String) MRG_TestFactory.keptValue(keepId, 'Contact', 'MailingState'),
			'an invalid resolver class should leave the kept value unchanged');
	}

	static testMethod void testSampleResolverKeepsLongest() {
		Contact keep = new Contact(LastName='K', MailingStreet='ab');
		Contact merged = new Contact(LastName='M', MailingStreet='abcd');
		MRG_FieldKeepContext ctx = new MRG_FieldKeepContext('Contact', 'MailingStreet', keep, keep, new List<SObject>{ merged });
		Object result = new MRG_SampleFieldKeepRule().resolveValue(ctx);
		system.assertEquals('abcd', (String) result, 'sample resolver keeps the longest value');
		system.assertEquals('ab', (String) ctx.currentValue, 'context exposes the rule-decided current value');
	}
}
