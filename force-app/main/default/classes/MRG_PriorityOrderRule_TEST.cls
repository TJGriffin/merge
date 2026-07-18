/**
* @author tj@tjgriffin.com
* @group Merge
* @description unit + end-to-end tests for the Priority Order preservation rule (#91): the field
* keeps the highest-priority value (per a ranked semicolon-delimited list) across the merge group.
*/
@isTest
private class MRG_PriorityOrderRule_TEST {

	static final String ORDER = 'Owner;Manager;Employee';

	static testMethod void testPriorityRank() {
		system.assertEquals(0, MRG_Merge_SVC.priorityRank('Owner', ORDER), 'first listed value ranks 0');
		system.assertEquals(1, MRG_Merge_SVC.priorityRank('Manager', ORDER), 'second listed value ranks 1');
		system.assertEquals(2, MRG_Merge_SVC.priorityRank('Employee', ORDER), 'third listed value ranks 2');
		system.assertEquals(0, MRG_Merge_SVC.priorityRank(' owner ', ORDER), 'match is trimmed and case-insensitive');
		system.assert(MRG_Merge_SVC.priorityRank('Partner', ORDER) > 2, 'unlisted value ranks below all listed values');
		system.assert(MRG_Merge_SVC.priorityRank('Owner', null) > 0, 'blank list -> everything unlisted');
		system.assert(MRG_Merge_SVC.priorityRank(null, ORDER) > 2, 'null value -> unlisted');
	}

	static testMethod void testPriorityRankSkipsBlankSegments() {
		system.assertEquals(0, MRG_Merge_SVC.priorityRank('Owner', ' Owner ; ; Manager '), 'blank segments are skipped');
		system.assertEquals(1, MRG_Merge_SVC.priorityRank('Manager', ' Owner ; ; Manager '), 'ranks skip blank segments');
	}

	static testMethod void testPriorityBeats() {
		system.assert(MRG_Merge_SVC.priorityBeats('Owner', 'Manager', ORDER), 'higher priority merge value wins');
		system.assert(!MRG_Merge_SVC.priorityBeats('Employee', 'Manager', ORDER), 'lower priority merge value loses');
		system.assert(!MRG_Merge_SVC.priorityBeats('Manager', 'Manager', ORDER), 'equal values keep the surviving value');
		system.assert(MRG_Merge_SVC.priorityBeats('Employee', 'Partner', ORDER), 'listed merge value beats an unlisted kept value');
		system.assert(!MRG_Merge_SVC.priorityBeats('Partner', 'Employee', ORDER), 'unlisted merge value never beats a listed kept value');
		system.assert(!MRG_Merge_SVC.priorityBeats('Partner', 'Intern', ORDER), 'two unlisted values keep the surviving value');
		system.assert(MRG_Merge_SVC.priorityBeats('Employee', null, ORDER), 'a null kept value always takes the merge value');
		system.assert(!MRG_Merge_SVC.priorityBeats(null, 'Employee', ORDER), 'a null merge value never wins');
	}

	static testMethod void testContactPriorityOrderEndToEnd() {
		// keep holds the LOWEST priority value; the highest across the group must survive
		List<Contact> cons = MRG_TestFactory.contacts(3);
		Id keepId = cons[0].Id;
		Id mergeId1 = cons[1].Id;
		Id mergeId2 = cons[2].Id;
		update new List<Contact>{
			new Contact(Id=keepId, LeadSource='Employee'),
			new Contact(Id=mergeId1, LeadSource='Manager'),
			new Contact(Id=mergeId2, LeadSource='Owner')
		};
		MergeFieldSetting__mdt setting = MRG_TestFactory.mergeField('Contact','LeadSource','Preserve','Priority Order');
		setting.PriorityOrder__c = ORDER;
		MRG_TestFactory.registerMergeFields(new List<MergeFieldSetting__mdt>{ setting });
		List<MergeCandidate__c> candidates = MRG_TestFactory.mergeCandidatePairs(keepId, new List<Id>{ mergeId1, mergeId2 }, 'Contact');

		Test.startTest();
		MRG_TestFactory.runMerge(candidates, 'Contact');
		Test.stopTest();

		system.assertEquals('Owner', (String) MRG_TestFactory.keptValue(keepId,'Contact','LeadSource'),
			'Priority Order keeps the highest-priority value across the merge group');
		system.assert(MRG_TestFactory.historyByField(keepId).containsKey('leadsource'),
			'changed preserved field should be tracked');
	}

	static testMethod void testContactPriorityOrderKeptValueAlreadyHighest() {
		// keep already holds the highest priority value; nothing should change
		List<Contact> cons = MRG_TestFactory.contacts(2);
		Id keepId = cons[0].Id;
		Id mergeId = cons[1].Id;
		update new List<Contact>{
			new Contact(Id=keepId, LeadSource='Owner'),
			new Contact(Id=mergeId, LeadSource='Employee')
		};
		MergeFieldSetting__mdt setting = MRG_TestFactory.mergeField('Contact','LeadSource','Preserve','Priority Order');
		setting.PriorityOrder__c = ORDER;
		MRG_TestFactory.registerMergeFields(new List<MergeFieldSetting__mdt>{ setting });
		MergeCandidate__c mc = MRG_TestFactory.mergeCandidate(keepId, mergeId, 'Contact');

		Test.startTest();
		MRG_TestFactory.runMerge(new List<MergeCandidate__c>{ mc }, 'Contact');
		Test.stopTest();

		system.assertEquals('Owner', (String) MRG_TestFactory.keptValue(keepId,'Contact','LeadSource'),
			'the kept record already holds the highest-priority value');
	}

	static testMethod void testContactPriorityOrderUnlistedMergeValueLoses() {
		// merged record's value is not in the list; the kept listed value survives
		List<Contact> cons = MRG_TestFactory.contacts(2);
		Id keepId = cons[0].Id;
		Id mergeId = cons[1].Id;
		update new List<Contact>{
			new Contact(Id=keepId, LeadSource='Employee'),
			new Contact(Id=mergeId, LeadSource='Partner')
		};
		MergeFieldSetting__mdt setting = MRG_TestFactory.mergeField('Contact','LeadSource','Preserve','Priority Order');
		setting.PriorityOrder__c = ORDER;
		MRG_TestFactory.registerMergeFields(new List<MergeFieldSetting__mdt>{ setting });
		MergeCandidate__c mc = MRG_TestFactory.mergeCandidate(keepId, mergeId, 'Contact');

		Test.startTest();
		MRG_TestFactory.runMerge(new List<MergeCandidate__c>{ mc }, 'Contact');
		Test.stopTest();

		system.assertEquals('Employee', (String) MRG_TestFactory.keptValue(keepId,'Contact','LeadSource'),
			'an unlisted merge value never displaces a listed kept value');
	}
}
