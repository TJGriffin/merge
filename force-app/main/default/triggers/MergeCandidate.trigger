trigger MergeCandidate on MergeCandidate__c (after insert, after update, before insert, before update, after delete, before delete) {
    String objectName = trigger.isDelete ? trigger.old.getSObjectType().getDescribe().getName() : trigger.new.getSObjectType().getDescribe().getName();
	MRG_TriggerHandler_SVC.runTrigger(Trigger.isBefore, Trigger.isAfter, Trigger.isInsert, Trigger.isUpdate, Trigger.isDelete, Trigger.isUndelete, (List<SObject>) Trigger.new, (List<SObject>) Trigger.old, objectName);    
}