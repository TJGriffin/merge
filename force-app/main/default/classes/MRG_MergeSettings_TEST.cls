@isTest
private class MRG_MergeSettings_TEST {
    static testMethod void testController() {
        MRG_Merge_TEST.createMergeFields();
        test.startTest();
        List<MRG_MergeSettings_CTRL.profileWrap> profiles = MRG_MergeSettings_CTRL.getProfiles();
        List<MRG_MergeSettings_CTRL.userWrap> users = MRG_MergeSettings_CTRL.getUsers();
        List<MRG_Merge_SVC.mergeFieldWrap> mergeFields =  MRG_MergeSettings_CTRL.getAllMergeFields();
        MRG_Merge_SVC.mergeSetting settings = MRG_MergeSettings_CTRL.getMergeSetting();
        system.assert(mergeFields.size()>0);
        mergeFields.clear();
        mergeFields = MRG_MergeSettings_CTRL.getAllMergeFields('t','Contact');
        system.assert(mergeFields.size()>0);
        List<MRG_Merge_SVC.objectField> objectFields = MRG_MergeSettings_CTRL.getObjectFields('Contact');
        system.assert(objectfields.size()>0);
        
        String jobId = MRG_MergeSettings_CTRL.saveMergeFields(JSON.serialize(mergeFields));
        test.stopTest();

    }
    static testMethod void testController2() {
        MRG_Merge_TEST.createMergeFields();
        test.startTest();
        List<MRG_MergeSettings_CTRL.previewField> previewFields = MRG_MergeSettings_CTRL.getAllPreviewFields('Contact');
        
        String jobId = MRG_MergeSettings_CTRL.savePreviewFieldsSettings(JSON.serialize(previewFields));
        test.stopTest();

    }

    static testMethod void testAutoMergeOrphanedHouseholdsSettingRoundTrip() {
        // blank setting shows the default list
        MRG_Merge_SVC.mergeSetting settings = MRG_MergeSettings_CTRL.getMergeSetting();
        system.assertEquals(MRG_Merge_SVC.DEFAULT_ORPHANED_HOUSEHOLD_TYPES, settings.autoMergeOrphanedHouseholds);

        settings.autoMergeOrphanedHouseholds = 'Family,HH_Account';
        test.startTest();
        MRG_Merge_SVC.mergeSetting saved = MRG_MergeSettings_CTRL.saveMergeSettings(JSON.serialize(settings));
        test.stopTest();

        system.assertEquals('Family,HH_Account', saved.autoMergeOrphanedHouseholds);
        system.assertEquals('Family,HH_Account', MergeControlSettings__c.getOrgDefaults().AutoMergeOrphanedHouseholds__c);
        system.assertEquals('Family,HH_Account', MRG_MergeSettings_CTRL.getMergeSetting().autoMergeOrphanedHouseholds);
    }

    static testMethod void testDisableNpspTriggersOnOrphanMergeSettingRoundTrip() {
        MRG_Merge_SVC.mergeSetting settings = MRG_MergeSettings_CTRL.getMergeSetting();
        system.assertEquals(false, settings.disableNpspTriggersOnOrphanMerge, 'off by default');
        system.assertEquals(false, MRG_Merge_SVC.getDisableNpspTriggersOnOrphanMerge());

        settings.disableNpspTriggersOnOrphanMerge = true;
        test.startTest();
        MRG_Merge_SVC.mergeSetting saved = MRG_MergeSettings_CTRL.saveMergeSettings(JSON.serialize(settings));
        test.stopTest();

        system.assertEquals(true, saved.disableNpspTriggersOnOrphanMerge);
        system.assertEquals(true, MRG_Merge_SVC.getDisableNpspTriggersOnOrphanMerge());
        system.assertEquals(true, MRG_MergeSettings_CTRL.getMergeSetting().disableNpspTriggersOnOrphanMerge);
    }

    static testMethod void testResetDefaultAddressOnOrphanMergeSettingRoundTrip() {
        MRG_Merge_SVC.mergeSetting settings = MRG_MergeSettings_CTRL.getMergeSetting();
        system.assertEquals(false, settings.resetDefaultAddressOnOrphanMerge, 'off by default');
        system.assertEquals(false, MRG_Merge_SVC.getResetDefaultAddressOnOrphanMerge());

        settings.resetDefaultAddressOnOrphanMerge = true;
        test.startTest();
        MRG_Merge_SVC.mergeSetting saved = MRG_MergeSettings_CTRL.saveMergeSettings(JSON.serialize(settings));
        test.stopTest();

        system.assertEquals(true, saved.resetDefaultAddressOnOrphanMerge);
        system.assertEquals(true, MRG_Merge_SVC.getResetDefaultAddressOnOrphanMerge());
        system.assertEquals(true, MRG_MergeSettings_CTRL.getMergeSetting().resetDefaultAddressOnOrphanMerge);
    }

    static testMethod void testMergeHouseholdsWithMembersSettingsRoundTrip() {
        MRG_Merge_SVC.mergeSetting settings = MRG_MergeSettings_CTRL.getMergeSetting();
        system.assertEquals(false, settings.mergeHouseholdsWithMembers, 'off by default');
        system.assertEquals(false, settings.mergeHouseholdsRequireSameAddress, 'off by default');
        system.assertEquals(null, settings.mergeHouseholdsMaxOtherMembers, 'no limit by default');
        system.assertEquals(false, MRG_Merge_SVC.getMergeHouseholdsWithMembers());
        system.assertEquals(false, MRG_Merge_SVC.getMergeHouseholdsRequireSameAddress());
        system.assertEquals(null, MRG_Merge_SVC.getMergeHouseholdsMaxOtherMembers());

        settings.mergeHouseholdsWithMembers = true;
        settings.mergeHouseholdsRequireSameAddress = true;
        settings.mergeHouseholdsMaxOtherMembers = 2;
        test.startTest();
        MRG_Merge_SVC.mergeSetting saved = MRG_MergeSettings_CTRL.saveMergeSettings(JSON.serialize(settings));
        test.stopTest();

        system.assertEquals(true, saved.mergeHouseholdsWithMembers);
        system.assertEquals(true, saved.mergeHouseholdsRequireSameAddress);
        system.assertEquals(2, saved.mergeHouseholdsMaxOtherMembers);
        system.assertEquals(true, MRG_Merge_SVC.getMergeHouseholdsWithMembers());
        system.assertEquals(true, MRG_Merge_SVC.getMergeHouseholdsRequireSameAddress());
        system.assertEquals(2, MRG_Merge_SVC.getMergeHouseholdsMaxOtherMembers());
        MRG_Merge_SVC.mergeSetting reread = MRG_MergeSettings_CTRL.getMergeSetting();
        system.assertEquals(true, reread.mergeHouseholdsWithMembers);
        system.assertEquals(2, reread.mergeHouseholdsMaxOtherMembers);

        reread.mergeHouseholdsMaxOtherMembers = null;
        MRG_MergeSettings_CTRL.saveMergeSettings(JSON.serialize(reread));
        system.assertEquals(null, MRG_Merge_SVC.getMergeHouseholdsMaxOtherMembers(), 'blank clears the limit');
    }

    static testMethod void testHouseholdMergeUsesKeepRulesSettingRoundTrip() {
        MRG_Merge_SVC.mergeSetting settings = MRG_MergeSettings_CTRL.getMergeSetting();
        system.assertEquals(false, settings.householdMergeUsesKeepRules, 'off by default');
        system.assertEquals(false, MRG_Merge_SVC.getHouseholdMergeUsesKeepRules());

        settings.householdMergeUsesKeepRules = true;
        test.startTest();
        MRG_Merge_SVC.mergeSetting saved = MRG_MergeSettings_CTRL.saveMergeSettings(JSON.serialize(settings));
        test.stopTest();

        system.assertEquals(true, saved.householdMergeUsesKeepRules);
        system.assertEquals(true, MRG_Merge_SVC.getHouseholdMergeUsesKeepRules());
        system.assertEquals(true, MRG_MergeSettings_CTRL.getMergeSetting().householdMergeUsesKeepRules);
    }
}
