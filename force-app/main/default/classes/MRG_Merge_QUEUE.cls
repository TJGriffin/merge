/**
* @author tj@tjgriffin.com
* @date 2020
* @group Merge
* @description queueable to handle merge processing
*/
public with sharing class MRG_Merge_QUEUE implements Queueable {
	/*******************************************************************************************************
	* @description JSON representation of the deleted contacts
    */
    public String deletedContactJSON;
	/*******************************************************************************************************
	* @description objectType
    */
    public String objectType;
	/*******************************************************************************************************
	* @description constructor
    */
    public MRG_Merge_QUEUE(String deletedContactJSON, String objectType) {
        this.deletedContactJSON = deletedContactJSON;
        this.objectType = objectType;
    }

	/*******************************************************************************************************
	* @description execute method
    * @param context the queueable context
    */
    public void execute(QueueableContext context) {
        MRG_Merge_SVC.createMergeRecords((List<SObject>) JSON.deserialize(deletedContactJSON,List<SObject>.class), objectType);

    }
}
