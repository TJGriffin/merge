
@isTest
private class MRG_MergeCandidate_TEST {
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
            Object__c = 'Contact',
            Rule__c = 'test',
            Status__c = 'New',
            AutoMerge__c = true
        );
        insert mc;

	}
    @isTest
    static void testBatch() {
        test.startTest();
        Database.executeBatch(new MRG_MergeCandidate_BATCH(), 100);
        test.stopTest();
    }
    @isTest
    static void testBatch2() {
        List<Contact> cons = [SELECT Id FROM Contact];
        delete cons[0];
        test.startTest();
        Database.executeBatch(new MRG_MergeCandidate_BATCH(), 100);
        test.stopTest();
    }
}