@isTest
private class MRG_BatchControl_TEST {
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

    @isTest
    static void testCTRLRunScan() {
        test.startTest();
        MRG_BatchControl_CTRL.runScan();
        test.stopTest();
    }
    @isTest
    static void testCTRLRunMerge() {
        test.startTest();
        MRG_BatchControl_CTRL.autoMerge();
        test.stopTest();
    }

    @isTest 
    static void testCTRLScheduleJob(){
        test.startTest();
        MRG_BatchControl_CTRL.scheduleJob('Duplicate Scan','nightly');
        test.stopTest();
    }
    @isTest 
    static void testCTRLScheduleJob2(){
        test.startTest();
        MRG_BatchControl_CTRL.scheduleJob('Duplicate Merge','nightly');
        test.stopTest();
    }

    @isTest
    static void testCTRLgetScheduledJobs(){
        MRG_BatchControl_CTRL.scheduleJob('Duplicate Scan','nightly');
        test.startTest();
        List<MRG_BatchControl_SVC.scheduledJob> jobs = MRG_BatchControl_CTRL.getScheduledJobs();

        test.stopTest();
    }
}