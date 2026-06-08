/**
* @author tj@tjgriffin.com
* @group Merge
* @description covers the auto-merge pipeline and trigger gating. The scan path itself depends on
* Datacloud.FindDuplicates (not mockable without an injection seam, and unverifiable under the
* current no-deploy constraint), so this focuses on the robustly testable behavior: auto-merge
* batch filtering, trigger-disable gating, and not-a-duplicate exclusion. Scan-produced candidate
* pairing (the executable proof for bug #6) is a documented gap pending a Datacloud injection seam.
*/
@isTest
private class MRG_ScanPipeline_TEST {

	static testMethod void testAutoMergeBatchOnlyProcessesEligible() {
		// eligible: New + AutoMerge + not-a-duplicate=false
		List<Account> eligible = MRG_TestFactory.accounts(2);
		MergeCandidate__c eligibleMc = MRG_TestFactory.mergeCandidate(eligible[0].Id, eligible[1].Id, 'Account');

		// ineligible: AutoMerge=false
		List<Account> manualOnly = MRG_TestFactory.accounts(2);
		MergeCandidate__c manualMc = MRG_TestFactory.mergeCandidate(manualOnly[0].Id, manualOnly[1].Id, 'Account');
		manualMc.AutoMerge__c = false;

		// ineligible: marked not a duplicate
		List<Account> dismissed = MRG_TestFactory.accounts(2);
		MergeCandidate__c dismissedMc = MRG_TestFactory.mergeCandidate(dismissed[0].Id, dismissed[1].Id, 'Account');
		dismissedMc.NotADuplicate__c = true;
		update new List<MergeCandidate__c>{ manualMc, dismissedMc };

		MRG_TestFactory.registerMergeFields(new List<MergeFieldSetting__mdt>());

		Test.startTest();
		Database.executeBatch(new MRG_DuplicateMerge_BATCH(new Set<String>{'Account'}));
		Test.stopTest();

		system.assertEquals('Processed', [SELECT Status__c FROM MergeCandidate__c WHERE Id=:eligibleMc.Id].Status__c,
			'eligible auto-merge candidate should be processed');
		system.assertEquals('New', [SELECT Status__c FROM MergeCandidate__c WHERE Id=:manualMc.Id].Status__c,
			'AutoMerge=false candidate should be left for manual review');
		system.assertEquals('New', [SELECT Status__c FROM MergeCandidate__c WHERE Id=:dismissedMc.Id].Status__c,
			'not-a-duplicate candidate should be skipped');
	}

	static testMethod void testTriggerGatingByObject() {
		MergeControlSettings__c settings = MRG_Merge_SVC.getSettings();
		settings.DisableAccountTrigger__c = true;
		settings.DisableContactTrigger__c = false;
		upsert settings;

		system.assertEquals(true, MRG_Merge_SVC.getTriggerDisabled('Account'),
			'Account trigger should report disabled');
		system.assertEquals(false, MRG_Merge_SVC.getTriggerDisabled('Contact'),
			'Contact trigger should report enabled');
	}

	static testMethod void testTriggerGatingByUser() {
		MergeControlSettings__c settings = MRG_Merge_SVC.getSettings();
		settings.DisableForUsers__c = UserInfo.getUserId();
		upsert settings;

		system.assertEquals(true, MRG_Merge_SVC.getTriggerDisabled('Account'),
			'trigger should be disabled for the current user');
	}

	static testMethod void testTriggerGatingByProfile() {
		MergeControlSettings__c settings = MRG_Merge_SVC.getSettings();
		settings.DisableForProfiles__c = UserInfo.getProfileId();
		upsert settings;

		system.assertEquals(true, MRG_Merge_SVC.getTriggerDisabled('Contact'),
			'trigger should be disabled for the current profile');
	}

	static testMethod void testNotADuplicateExcludedFromList() {
		List<Account> accs = MRG_TestFactory.accounts(2);
		MergeCandidate__c mc = MRG_TestFactory.mergeCandidate(accs[0].Id, accs[1].Id, 'Account');
		mc.Rule__c = 'test';
		update mc;

		Integer before = MRG_DuplicateMerge_CTRL.getCount('Account','test');

		// dismiss it
		MRG_DuplicateMerge_CTRL.removeRecord(mc.Id);

		Integer after = MRG_DuplicateMerge_CTRL.getCount('Account','test');
		system.assertEquals(before - 1, after,
			'a candidate marked not-a-duplicate should drop out of the count');
	}
}
