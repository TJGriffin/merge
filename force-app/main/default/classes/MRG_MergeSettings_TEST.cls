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
}
