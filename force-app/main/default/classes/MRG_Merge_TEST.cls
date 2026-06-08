@isTest
public class MRG_Merge_TEST {
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

	static testMethod void testContactMerge() {
		createMergeFields();
		// build the two records explicitly so keep/merge values and ages are unambiguous.
		// keep = older record; merge = newer record.
		List<Contact> cons = new List<Contact>{
			new Contact(FirstName='Keep', LastName='KeepLast', Email='keep@test.com',
				MailingCity='Austin', MailingState='TX', MailingPostalCode='78751',
				Birthdate=Date.Today().addDays(-1200)),
			new Contact(FirstName='Merge', LastName='MergeLast', Email='merge@test.com',
				MailingStreet='123 Main Street', MailingState='CA', MailingPostalCode='78754',
				HasOptedOutOfEmail=true, Birthdate=Date.Today().addDays(-500))
		};
		insert cons;
		Id keepId = cons[0].Id;
		Id mergeId = cons[1].Id;
		Test.setCreatedDate(keepId, Datetime.now().addDays(-30)); // keep is oldest
		Test.setCreatedDate(mergeId, Datetime.now().addDays(-1));  // merge is newest

		MergeCandidate__c mc = new MergeCandidate__c(
			KeepRecordId__c = keepId,
			KeepName__c = 'Keep',
			MergeRecordId__c = mergeId,
			Object__c = 'Contact',
			Rule__c = 'test',
			Status__c = 'New',
			AutoMerge__c = true
		);
		insert mc;

		test.startTest();
		// drive the merge through the production service path so the in-memory merge field settings
		// apply (the async ContactMerge trigger path would run in a fresh context without them).
		// disableTriggers=true suppresses the delete-trigger queue job so processing stays in this txn.
		MRG_Merge_SVC.processMergesFromBatch(new List<MergeCandidate__c>{ mc }, 'Contact', true);
		test.stopTest();

		Contact keptCon = [
			SELECT Id, LastName, Email, MailingStreet, MailingCity, MailingState,
				MailingPostalCode, Birthdate
			FROM Contact WHERE Id=:keepId
		];

		Map<String, MergeFieldHistory__c> mergeMap = new Map<String, MergeFieldHistory__c>();
		for(MergeFieldHistory__c mergeField: [
			SELECT Id, KeptRecordId__c, KeptValue__c, MergeValue__c, MergeValueType__c
			FROM MergeFieldHistory__c
		]) {
			mergeMap.put(mergeField.MergeValueType__c.trim().toLowerCase(), mergeField);
		}

		system.assert(mergeMap.size()>0, 'tracked field history should be created');
		MergeFieldHistory__c emailMergeField = mergeMap.get('email');
		system.assertNotEquals(null, emailMergeField, 'email is a tracked field and should be recorded');
		system.assertEquals('merge@test.com', emailMergeField.MergeValue__c, 'merged email recorded');
		system.assertEquals('keep@test.com', emailMergeField.KeptValue__c, 'kept email recorded');
		system.assertEquals(keepId, emailMergeField.KeptRecordId__c, 'kept record id recorded');

		system.assertEquals(Date.Today().addDays(-1200), keptCon.Birthdate, 'Smallest keeps the earlier birthdate');
		system.assertEquals('78754', keptCon.MailingPostalCode, 'Largest keeps the larger postal code');
		system.assertEquals('KeepLast', keptCon.LastName, 'Oldest keeps the older (kept) record last name');
		system.assertEquals('CA', keptCon.MailingState, 'Newest keeps the newer record mailing state');
		system.assert(String.isNotBlank(keptCon.MailingStreet), 'blank street filled from merged record');
		system.assert(String.isNotBlank(keptCon.MailingCity), 'kept city retained');
	}


	static testMethod void testCoerceOverrideValue() {
		// blank -> null
		system.assertEquals(null, MRG_Merge_SVC.coerceOverrideValue('STRING', null));
		system.assertEquals(null, MRG_Merge_SVC.coerceOverrideValue('STRING', ''));
		// string / id pass through
		system.assertEquals('hello', MRG_Merge_SVC.coerceOverrideValue('STRING', 'hello'));
		system.assertEquals('001000000000000AAA', MRG_Merge_SVC.coerceOverrideValue('ID', '001000000000000AAA'));
		// boolean
		system.assertEquals(true, MRG_Merge_SVC.coerceOverrideValue('BOOLEAN', 'true'));
		// numeric
		system.assertEquals(12.5, (Double) MRG_Merge_SVC.coerceOverrideValue('DOUBLE', '12.5'));
		system.assertEquals(7, (Integer) MRG_Merge_SVC.coerceOverrideValue('INTEGER', '7'));
		// date / datetime from raw (unquoted) strings -- the case that previously threw
		system.assertEquals(Date.newInstance(2020,1,15), (Date) MRG_Merge_SVC.coerceOverrideValue('DATE', '2020-01-15'));
		system.assertEquals(Datetime.valueOf('2020-01-15 13:30:00'),
			(Datetime) MRG_Merge_SVC.coerceOverrideValue('DATETIME', '2020-01-15 13:30:00'));
		// unparseable value -> null (does not throw)
		system.assertEquals(null, MRG_Merge_SVC.coerceOverrideValue('DATE', 'not-a-date'));
		system.assertEquals(null, MRG_Merge_SVC.coerceOverrideValue('INTEGER', 'abc'));
	}

	static testMethod void testValuesAreEqual() {
		// nulls
		system.assert(MRG_Merge_SVC.valuesAreEqual(null, null), 'two nulls are equal');
		system.assert(!MRG_Merge_SVC.valuesAreEqual(null, 'x'), 'one null is not equal');
		system.assert(!MRG_Merge_SVC.valuesAreEqual('x', null), 'one null is not equal');
		// equal values across types
		system.assert(MRG_Merge_SVC.valuesAreEqual('abc', 'abc'), 'equal strings');
		system.assert(MRG_Merge_SVC.valuesAreEqual(5, 5), 'equal integers');
		system.assert(MRG_Merge_SVC.valuesAreEqual(true, true), 'equal booleans');
		Date d = Date.newInstance(2020,1,1);
		system.assert(MRG_Merge_SVC.valuesAreEqual(d, Date.newInstance(2020,1,1)), 'equal dates');
		// different values
		system.assert(!MRG_Merge_SVC.valuesAreEqual('abc', 'abd'), 'different strings');
		system.assert(!MRG_Merge_SVC.valuesAreEqual(5, 6), 'different integers');
		system.assert(!MRG_Merge_SVC.valuesAreEqual(true, false), 'different booleans');
	}

	static testMethod void testFieldHistoryCarriesIntoPerKeepResult() {
		List<Contact> cons = [SELECT Id FROM Contact ORDER BY CreatedDate ASC];
		Id keepId = cons[0].Id;
		Id mergeId = cons[1].Id;

		MergeFieldHistory__c history = new MergeFieldHistory__c(
			KeptRecordId__c = keepId,
			MergedRecordId__c = mergeId,
			KeptValue__c = 'kept',
			MergeValue__c = 'merged',
			MergeValueType__c = 'Email'
		);
		MRG_Merge_SVC.mergeHistoryResult result = new MRG_Merge_SVC.mergeHistoryResult(
			new List<SObject>(),
			new List<MergeFieldHistory__c>{ history }
		);
		Map<Id, Set<Id>> mergeKeyMap = new Map<Id, Set<Id>>{ keepId => new Set<Id>{ mergeId } };

		test.startTest();
		Map<Id, MRG_Merge_SVC.mergeHistoryResult> byKeep =
			MRG_Merge_SVC.getMergeHistoryResultByKeepId(result, mergeKeyMap);
		test.stopTest();

		system.assert(byKeep.containsKey(keepId), 'result should be keyed by keep id');
		system.assertEquals(1, byKeep.get(keepId).fieldHistory.size(),
			'field history must carry into the per-keep result, not be dropped');
		system.assertEquals('Email', byKeep.get(keepId).fieldHistory[0].MergeValueType__c);
	}

	static testMethod void testAccountMerge() {
		Contact oldestCon;
		Contact newestCon;
		Contact mergedCon;
	
		createMergeFields();
		List<Account> accs = [
			SELECT
			Id,
			Name
			FROM Account
		];
		List<Contact> cons = [
			SELECT
			Id,
			FirstName,
			LastNAme,
			Email,
			MailingStreet,
			MailingCity,
			MailingState,
			MailingPostalCode,
			Birthdate
			FROM Contact	
		];
		test.startTest();

		merge accs[0] accs[1];
		test.stopTest();

	}
	static testMethod void testTriggers(){
		MergeControlSettings__c settings = MRG_Merge_SVC.getSettings();
		settings.DisableAccountTrigger__c = true;
		settings.DisableContactTrigger__c = true;
		upsert settings;

		test.startTest();
		List<Account> acc = [SELECT Id FROM Account LIMIT 1];
		List<Contact> con = [SELECT Id FROM Contact WHERE AccountId = null LIMIT 1];
		// delete the contact first: deleting the account can cascade to related contacts in this org,
		// which would leave the contact already-deleted (ENTITY_IS_DELETED) by the time we reach it
		delete con;
		delete acc;
		test.stopTest();
	}
	@testvisible private static void createMergeFields() {


		List<MergeFieldSetting__mdt> mergeFields = new List<MergeFieldSetting__mdt>();
		mergeFields.add(createTestMergeField('Contact','FirstName','Track','Oldest'));
		mergeFields.add(createTestMergeField('Contact','LastName','Preserve','Oldest'));
		mergeFields.add(createTestMergeField('Contact','Email','Track','Oldest'));
		mergeFields.add(createTestMergeField('Contact','MailingState','Preserve','Newest'));
		mergeFields.add(createTestMergeField('Contact','MailingPostalCode','Preserve','Largest'));
		mergeFields.add(createTestMergeField('Contact','Birthdate','Preserve','Smallest'));
		mergeFields.add(createTestMergeField('Account','Name','Track','Smallest'));
		MRG_Merge_SVC.mergeFields = mergeFields;


		List<PreviewFields__mdt> previewFields = new List<PreviewFields__mdt>();
		previewFields.add(createTestPrevieField('Contact','Email'));
		MRG_Merge_SVC.previewFields = previewFields;
	}
	private static PreviewFields__mdt createTestPrevieField(String objectName, String fieldName){
		PreviewFields__mdt previewField = new PreviewFields__mdt();
		Map<String, Object> previewFieldFields = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(previewField));
		previewFieldFields.put(PreviewFields__mdt.Label.getDescribe().getName(),'test'+fieldName);
		previewFieldFields.put(PreviewFields__mdt.DeveloperName.getDescribe().getName(),'test'+fieldName);
		previewFieldFields.put(PreviewFields__mdt.Disable__c.getDescribe().getName(),true);
		previewFieldFields.put('Object__r',new Map<String, Object>{
			'attributes' => new Map<String, Object>{
				'type' => 'EntityDefinition'
			},
			'QualifiedAPIName'=>objectName
		});
		previewFieldFields.put('Field__r',new Map<String, Object>{
			'attributes' => new Map<String, Object>{
				'type' => 'EntityParticle'
			},
			'QualifiedAPIName'=>fieldName
		});
		previewField = (PreviewFields__mdt) JSON.deserialize(JSON.serialize(previewFieldFields),PreviewFields__mdt.class);
		return previewField;

	}
	private static MergeFieldSetting__mdt createTestMergeField(String objectName, String fieldName, String type, String rule) {
		MergeFieldSetting__mdt mergeField = new MergeFieldSetting__mdt();
		Map<String, Object> mergeFieldFields = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(mergeField));
		mergeFieldFields.put(MergeFieldSetting__mdt.Label.getDescribe().getName(),'test'+fieldName);
		mergeFieldFields.put(MergeFieldSetting__mdt.DeveloperName.getDescribe().getName(),'test'+fieldName);
		mergeFieldFields.put(MergeFieldSetting__mdt.Type__c.getDescribe().getName(),type);
		mergeFieldFields.put(MergeFieldSetting__mdt.PreservationRule__c.getDescribe().getName(),rule);
		mergeFieldFields.put('Object__r',new Map<String, Object>{
			'attributes' => new Map<String, Object>{
				'type' => 'EntityDefinition'
			},
			'QualifiedAPIName'=>objectName
		});
		mergeFieldFields.put('Field__r',new Map<String, Object>{
			'attributes' => new Map<String, Object>{
				'type' => 'EntityParticle'
			},
			'QualifiedAPIName'=>fieldName
		});
		mergeField = (MergeFieldSetting__mdt) JSON.deserialize(JSON.serialize(mergeFieldFields),MergeFieldSetting__mdt.class);
		return mergeField;

	}

	
	
}