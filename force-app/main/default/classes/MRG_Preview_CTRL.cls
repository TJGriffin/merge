/**
* @author tj@tjgriffin.com
* @date 2020
* @group Merge
* @description Controller for previewing merges
*/
public with sharing class MRG_Preview_CTRL {
	/*******************************************************************************************************
	* @description gets the preview record for a merge
    * @param recordId the merge candidate recordid
	* @return mergePreview the preview record
	********************************************************************************************************/ 
    @AuraEnabled(cacheable=true)
    public static MRG_MergeCandidate getPreviewRecord(String recordId) {
        return MRG_MergeCandidate_SVC.getMergeCandidate(recordId);
    }



}
