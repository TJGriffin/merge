@isTest
private class CON_MergeSettings_TEST {
    static testMethod void testController() {
        CON_Merge_TEST.createMergeFields();
        test.startTest();
        List<CON_Merge_SVC.mergeFieldWrap> mergeFields =  CON_MergeSettings_CTRL.getAllMergeFields();
        system.assert(mergeFields.size()>0);
        mergeFields.clear();
        mergeFields = CON_MergeSettings_CTRL.getAllMergeFields('t','Contact');
        system.assert(mergeFields.size()>0);
        List<CON_Merge_SVC.objectField> objectFields = CON_MergeSettings_CTRL.getObjectFields('Contact');
        system.assert(objectfields.size()>0);
        
        String jobId = CON_MergeSettings_CTRL.saveMergeFields(JSON.serialize(mergeFields));
        test.stopTest();

    }
}
