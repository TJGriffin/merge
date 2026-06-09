/**
* @author tj@tjgriffin.com
* @group Merge
* @description tests for the fallback field on Track/Preserve settings (#34, re-homed): the losing
* value is routed into a configured fallback field on the kept record (only when empty) and recorded
* in Merge Field History with the target field.
*/
@isTest
private class MRG_FieldFallback_TEST {

	// in-memory Track/Preserve MergeFieldSetting with an optional fallback field, via JSON injection
	private static MergeFieldSetting__mdt fieldSetting(String objectName, String fieldName, String type, String rule, String fallbackField) {
		MergeFieldSetting__mdt mf = new MergeFieldSetting__mdt();
		Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(mf));
		m.put(MergeFieldSetting__mdt.Label.getDescribe().getName(), 'test'+fieldName);
		m.put(MergeFieldSetting__mdt.DeveloperName.getDescribe().getName(), 'test'+fieldName);
		m.put(MergeFieldSetting__mdt.Type__c.getDescribe().getName(), type);
		m.put(MergeFieldSetting__mdt.Disable__c.getDescribe().getName(), false);
		if(String.isNotBlank(rule))
			m.put(MergeFieldSetting__mdt.PreservationRule__c.getDescribe().getName(), rule);
		m.put('Object__r', new Map<String, Object>{ 'attributes' => new Map<String, Object>{ 'type' => 'EntityDefinition' }, 'QualifiedAPIName' => objectName });
		m.put('Field__r', new Map<String, Object>{ 'attributes' => new Map<String, Object>{ 'type' => 'EntityParticle' }, 'QualifiedAPIName' => fieldName });
		if(String.isNotBlank(fallbackField))
			m.put('FallbackField__r', new Map<String, Object>{ 'attributes' => new Map<String, Object>{ 'type' => 'EntityParticle' }, 'QualifiedAPIName' => fallbackField });
		return (MergeFieldSetting__mdt) JSON.deserialize(JSON.serialize(m), MergeFieldSetting__mdt.class);
	}

	static testMethod void testWrapperParsesFallbackField() {
		MRG_Merge_SVC.mergeFieldWrap mfw = new MRG_Merge_SVC.mergeFieldWrap(
			fieldSetting('Contact','Email','Track',null,'Description'));
		system.assertEquals('Description', mfw.fallbackField);
	}

	static testMethod void testTrackFallbackRoutesLosingValue() {
		// Track Email with fallback to Description: the merged (losing) email goes to Description
		List<Contact> cons = MRG_TestFactory.contacts(2);
		Id keepId = cons[0].Id;
		Id mergeId = cons[1].Id;
		update new List<Contact>{
			new Contact(Id=keepId, Email='keep@test.com', Description=null),
			new Contact(Id=mergeId, Email='lost@test.com')
		};
		MRG_Merge_SVC.mergeFields = new List<MergeFieldSetting__mdt>{
			fieldSetting('Contact','Email','Track',null,'Description')
		};
		MRG_Merge_SVC.previewFields = new List<PreviewFields__mdt>();

		MergeCandidate__c mc = MRG_TestFactory.mergeCandidate(keepId, mergeId, 'Contact');
		Test.startTest();
		MRG_TestFactory.runMerge(new List<MergeCandidate__c>{ mc }, 'Contact');
		Test.stopTest();

		system.assertEquals('lost@test.com', (String) MRG_TestFactory.keptValue(keepId,'Contact','Description'),
			'the losing (merged) email should be routed to the empty Description fallback field');
		// kept Email is untouched (track doesn't change the source field)
		system.assertEquals('keep@test.com', (String) MRG_TestFactory.keptValue(keepId,'Contact','Email'));

		// history records the value and the target field
		List<MergeFieldHistory__c> history = [
			SELECT MergeValueType__c, TargetField__c, KeptValue__c FROM MergeFieldHistory__c
			WHERE KeptRecordId__c=:keepId AND TargetField__c='Description'
		];
		system.assertEquals(1, history.size(), 'a fallback history entry with the target field');
		system.assertEquals('email', history[0].MergeValueType__c.toLowerCase(), 'source field recorded');
		system.assertEquals('lost@test.com', history[0].KeptValue__c);
	}

	static testMethod void testPreserveFallbackRoutesDisplacedValue() {
		// Preserve MailingState (Newest); the displaced (older, kept) value goes to the fallback field
		List<Contact> cons = MRG_TestFactory.contacts(2);
		Id keepId = cons[0].Id;   // older
		Id mergeId = cons[1].Id;  // newer
		MRG_TestFactory.setCreatedDate(keepId, Datetime.now().addDays(-30));
		MRG_TestFactory.setCreatedDate(mergeId, Datetime.now().addDays(-1));
		update new List<Contact>{
			new Contact(Id=keepId, MailingState='OLD', Description=null),
			new Contact(Id=mergeId, MailingState='NEW')
		};
		MRG_Merge_SVC.mergeFields = new List<MergeFieldSetting__mdt>{
			fieldSetting('Contact','MailingState','Preserve','Newest','Description')
		};
		MRG_Merge_SVC.previewFields = new List<PreviewFields__mdt>();

		MergeCandidate__c mc = MRG_TestFactory.mergeCandidate(keepId, mergeId, 'Contact');
		Test.startTest();
		MRG_TestFactory.runMerge(new List<MergeCandidate__c>{ mc }, 'Contact');
		Test.stopTest();

		// Newest preserved -> kept MailingState becomes NEW; the displaced OLD goes to the fallback
		system.assertEquals('NEW', (String) MRG_TestFactory.keptValue(keepId,'Contact','MailingState'),
			'Newest preserve wins onto the source field');
		system.assertEquals('OLD', (String) MRG_TestFactory.keptValue(keepId,'Contact','Description'),
			'the displaced value should be routed to the fallback field');
	}

	static testMethod void testFallbackSkipsWhenTargetNotEmpty() {
		List<Contact> cons = MRG_TestFactory.contacts(2);
		Id keepId = cons[0].Id;
		Id mergeId = cons[1].Id;
		update new List<Contact>{
			new Contact(Id=keepId, Email='keep@test.com', Description='already set'),
			new Contact(Id=mergeId, Email='lost@test.com')
		};
		MRG_Merge_SVC.mergeFields = new List<MergeFieldSetting__mdt>{
			fieldSetting('Contact','Email','Track',null,'Description')
		};
		MRG_Merge_SVC.previewFields = new List<PreviewFields__mdt>();

		MergeCandidate__c mc = MRG_TestFactory.mergeCandidate(keepId, mergeId, 'Contact');
		Test.startTest();
		MRG_TestFactory.runMerge(new List<MergeCandidate__c>{ mc }, 'Contact');
		Test.stopTest();

		system.assertEquals('already set', (String) MRG_TestFactory.keptValue(keepId,'Contact','Description'),
			'a non-empty fallback target must not be overwritten');
	}
}
