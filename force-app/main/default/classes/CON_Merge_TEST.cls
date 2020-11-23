@isTest
public class CON_Merge_TEST {
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
		merge cons[0] cons[1];
		test.stopTest();
		cons = [
			SELECT
			Id,
			FirstName,
			LastNAme,
			Email,
			HasOptedOutOfEmail,
			MailingStreet,
			MailingCity,
			MailingState,
			MailingPostalCode,
			Birthdate,
			CreatedDate,
			LastModifiedDate,
			IsDeleted,
			MasterRecordId
			FROM Contact
			ALL ROWS	
		];
		Map<String, Merge__c> mergeMap = new Map<String, Merge__c>();
		for(Merge__c mergeField: [
			SELECT 
			Id, 
			KeptRecordId__c,
			KeptValue__c,
			MergeValue__c,
			MergeValueType__c
			FROM Merge__c
		]) {
			mergeMap.put(mergeField.MergeValueType__c.trim().toLowerCase(), mergeField);
		}

		oldestcon = cons[0].CreatedDate < cons[1].CreatedDate ? cons[0] : cons[1];
		newestCon = oldestcon == cons[0] ? cons[1] : cons[0];
		mergedCon = cons[0].IsDeleted ? cons[0] : cons[1];
		Contact keptCon = !cons[0].isDeleted ? cons[0] : cons[1]; 

		system.assert(mergeMap.size()>0);
		Merge__c emailMergeField = mergeMap.get('email');
		system.assertEquals(emailMergeField.mergeValue__c,cons[1].Email);
		system.assertEquals(emailMergeField.keptValue__c,cons[0].Email);
		system.assertEquals(emailMergeField.keptRecordId__c,cons[0].Id);
		system.assertEquals(keptCon.BirthDate,Date.Today().addDays(-1200));
		system.assertEquals(keptCon.MailingPostalCode,'78754');
		system.assertEquals(keptCon.LastName,oldestCon.LastName);
		system.assertEquals(keptCon.MailingState,newestCon.MailingState);
		system.assert(String.isNotBlank(keptCon.MailingStreet));
		system.assert(String.isNotBlank(keptCon.MailingCity));
		system.assert(keptCon.HasOptedOutOfEmail);
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
	@testvisible private static void createMergeFields() {


		List<ContactMergeField__mdt> mergeFields = new List<ContactMergeField__mdt>();
		mergeFields.add(createTestMergeField('Contact','FirstName','Track','Oldest'));
		mergeFields.add(createTestMergeField('Contact','LastName','Preserve','Oldest'));
		mergeFields.add(createTestMergeField('Contact','Email','Track','Oldest'));
		mergeFields.add(createTestMergeField('Contact','MailingState','Preserve','Newest'));
		mergeFields.add(createTestMergeField('Contact','MailingPostalCode','Preserve','Largest'));
		mergeFields.add(createTestMergeField('Contact','Birthdate','Preserve','Smallest'));
		mergeFields.add(createTestMergeField('Account','Name','Track','Smallest'));
		CON_Merge_SVC.mergeFields = mergeFields;
	}

	private static ContactMergeField__mdt createTestMergeField(String objectName, String fieldName, String type, String rule) {
		ContactMergeField__mdt mergeField = new ContactMergeField__mdt();
		Map<String, Object> mergeFieldFields = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(mergeField));
		mergeFieldFields.put(ContactMergeField__mdt.Label.getDescribe().getName(),'test'+fieldName);
		mergeFieldFields.put(ContactMergeField__mdt.DeveloperName.getDescribe().getName(),'test'+fieldName);
		mergeFieldFields.put(ContactMergeField__mdt.Type__c.getDescribe().getName(),type);
		mergeFieldFields.put(ContactMergeField__mdt.PreservationRule__c.getDescribe().getName(),rule);
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
		mergeField = (ContactMergeField__mdt) JSON.deserialize(JSON.serialize(mergeFieldFields),ContactMergeField__mdt.class);
		return mergeField;

	}
	
}