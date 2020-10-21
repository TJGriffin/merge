/**
* @author tj@tjgriffin.com
* @date 2020
* @group Merge
* @description queueable to handle merge processing
*/
public with sharing class CON_Merge_QUEUE implements Queueable {
	/*******************************************************************************************************
	* @description JSON representation of the deleted contacts
    */
    public String deletedContactJSON;

	/*******************************************************************************************************
	* @description constructor
    */
    public CON_Merge_QUEUE(String deletedContactJSON) {
        this.deletedContactJSON = deletedContactJSON;
    }

	/*******************************************************************************************************
	* @description execute method
    * @param context the queueable context
    */
    public void execute(QueueableContext context) {
        ON_Merge_SVC.createMergeRecords((List<Contact>) JSON.deserialize(deletedContactJSON,List<Contact>.class));
    }
}
