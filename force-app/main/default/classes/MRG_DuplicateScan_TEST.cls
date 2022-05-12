@isTest
private class MRG_DuplicateScan_TEST {
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
    static testMethod void testBatch1() {
        test.startTest();
        database.executeBatch(new MRG_DuplicateScan_BATCH());
        test.stopTest();
    }
    static testMethod void testBatch2() {
        test.startTest();
        database.executeBatch(new MRG_DuplicateScan_BATCH(new Set<String>{'Contact'}));
        test.stopTest();
    }
}
