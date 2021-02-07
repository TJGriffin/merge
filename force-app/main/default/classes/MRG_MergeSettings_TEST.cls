@isTest
private class MRG_MergeSettings_TEST {
    static testMethod void testController() {
        MRG_Merge_TEST.createMergeFields();
        test.startTest();
        List<MRG_Merge_SVC.mergeFieldWrap> mergeFields =  MRG_MergeSettings_CTRL.getAllMergeFields();
        system.assert(mergeFields.size()>0);
        mergeFields.clear();
        mergeFields = MRG_MergeSettings_CTRL.getAllMergeFields('t','Contact');
        system.assert(mergeFields.size()>0);
        List<MRG_Merge_SVC.objectField> objectFields = MRG_MergeSettings_CTRL.getObjectFields('Contact');
        system.assert(objectfields.size()>0);
        
        String jobId = MRG_MergeSettings_CTRL.saveMergeFields(JSON.serialize(mergeFields));
        test.stopTest();

    }
}
