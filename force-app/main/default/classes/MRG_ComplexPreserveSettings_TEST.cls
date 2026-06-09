/**
* @author tj@tjgriffin.com
* @group Merge
* @description tests for Complex-rule config: mergeFieldWrap round-trip and getComplexPreserveRules
*/
@isTest
private class MRG_ComplexPreserveSettings_TEST {

	private static String conditionsJson() {
		return JSON.serialize(new List<MRG_KeepRecordRule.condition>{
			new MRG_KeepRecordRule.condition('HasOptedOutOfEmail','equals','true')
		});
	}

	/*******************************************************************************************************
	* @description builds an in-memory Complex MergeFieldSetting__mdt via JSON injection
	*/
	private static MergeFieldSetting__mdt buildComplexSetting(String objectName, String fieldName, String tieBreakField) {
		MergeFieldSetting__mdt mf = new MergeFieldSetting__mdt();
		Map<String, Object> fieldMap = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(mf));
		fieldMap.put(MergeFieldSetting__mdt.Label.getDescribe().getName(), 'test'+fieldName);
		fieldMap.put(MergeFieldSetting__mdt.DeveloperName.getDescribe().getName(), 'test'+fieldName);
		fieldMap.put(MergeFieldSetting__mdt.Type__c.getDescribe().getName(), 'Preserve');
		fieldMap.put(MergeFieldSetting__mdt.Disable__c.getDescribe().getName(), false);
		fieldMap.put(MergeFieldSetting__mdt.PreservationRule__c.getDescribe().getName(), 'Complex');
		fieldMap.put(MergeFieldSetting__mdt.FilterLogic__c.getDescribe().getName(), '1');
		fieldMap.put(MergeFieldSetting__mdt.Conditions__c.getDescribe().getName(), conditionsJson());
		fieldMap.put(MergeFieldSetting__mdt.TieBreakDirection__c.getDescribe().getName(), 'DESC');
		fieldMap.put('Object__r', new Map<String, Object>{
			'attributes' => new Map<String, Object>{ 'type' => 'EntityDefinition' }, 'QualifiedAPIName' => objectName });
		fieldMap.put('Field__r', new Map<String, Object>{
			'attributes' => new Map<String, Object>{ 'type' => 'EntityParticle' }, 'QualifiedAPIName' => fieldName });
		fieldMap.put('TieBreakField__r', new Map<String, Object>{
			'attributes' => new Map<String, Object>{ 'type' => 'EntityParticle' }, 'QualifiedAPIName' => tieBreakField });
		return (MergeFieldSetting__mdt) JSON.deserialize(JSON.serialize(fieldMap), MergeFieldSetting__mdt.class);
	}

	static testMethod void testWrapperParsesComplexFields() {
		MergeFieldSetting__mdt setting = buildComplexSetting('Contact', 'MailingStreet', 'Birthdate');
		MRG_Merge_SVC.mergeFieldWrap mfw = new MRG_Merge_SVC.mergeFieldWrap(setting);
		system.assertEquals('Complex', mfw.rule);
		system.assertEquals('1', mfw.filterLogic);
		system.assertEquals('Birthdate', mfw.tieBreakField);
		system.assertEquals('DESC', mfw.tieBreakDirection);
		system.assertEquals(1, mfw.conditions.size());
		system.assertEquals('HasOptedOutOfEmail', mfw.conditions[0].fieldName);
	}

	static testMethod void testGetComplexPreserveRulesFiltersByObjectAndType() {
		MRG_Merge_SVC.mergeFields = new List<MergeFieldSetting__mdt>{
			buildComplexSetting('Contact', 'MailingStreet', 'Birthdate'),
			buildComplexSetting('Account', 'Phone', 'CreatedDate')
		};
		List<MRG_ComplexPreserveRule> contactRules = MRG_Merge_SVC.getComplexPreserveRules('Contact');
		system.assertEquals(1, contactRules.size(), 'only the Contact complex rule');
		system.assertEquals('MailingStreet', contactRules[0].fieldName);
		system.assertEquals('Birthdate', contactRules[0].tieBreakField);
		system.assertEquals(1, contactRules[0].conditions.size());
		system.assertEquals(1, MRG_Merge_SVC.getComplexPreserveRules('Account').size());
		system.assertEquals(0, MRG_Merge_SVC.getComplexPreserveRules('Lead').size());
	}

	static testMethod void testToMdtRoundTripSerializesComplexFields() {
		MRG_Merge_SVC.mergeFieldWrap mfw = new MRG_Merge_SVC.mergeFieldWrap(
			buildComplexSetting('Contact', 'MailingStreet', 'Birthdate'));
		MergeFieldSetting__mdt setting = MRG_Merge_SVC.getMergeFieldFromObject(mfw);
		system.assertEquals('Complex', setting.PreservationRule__c);
		system.assertEquals('Preserve', setting.Type__c);
		system.assertEquals('DESC', setting.TieBreakDirection__c);
		system.assert(String.isNotBlank(setting.Conditions__c), 'conditions serialized');
		system.assertEquals('Birthdate', setting.TieBreakField__r.QualifiedAPIName, 'tie-break relationship injected');
		system.assertEquals('MailingStreet', setting.Field__r.QualifiedAPIName);
	}
}
