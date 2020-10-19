@isTest
private class CON_Merge_TEST {

	static testMethod void myUnitTest() {
		List<Contact> cons = new List<Contact>();
		Contact con = new Contact(LastName='Test',Email='test@test.com');	
		Contact con1 = new Contact(LastName='Test',Email='test1@test.com');	
		cons.add(con);
		cons.add(con1);
		insert cons;
		test.startTest();
		merge con con1;
		test.stopTest();
		List<Merge__c> merges = [SELECT Id, MergeValue__c FROM Merge__c WHERE MergedValueType__c='Email'];
		system.assert(merges.size()>0);
		system.assertEquals(merges[0].mergeValue__c,con1.Email);
	}
	
}