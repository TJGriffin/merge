/**
* @author tj@tjgriffin.com
* @group Merge
* @description batch that runs a grid action (merge / mergeAccounts / remove) over every merge
* candidate matching a filter — backs the grid's "select all (maximum)" actions (#84).
*/
public with sharing class MRG_GridAction_BATCH implements Database.Batchable<sObject>, Database.Stateful {
    @testvisible private String action;
    // bind targets referenced by MRG_Duplicate_SVC.getWhereClause(filter)
    @testvisible private String objectType;
    @testvisible private String ruleName;
    @testvisible private Decimal confidenceMin;
    @testvisible private Decimal confidenceMax;
    @testvisible private Boolean autoMerge;
    @testvisible private List<String> statuses;
    private MRG_Duplicate_SVC.candidateFilter filter;
    // original trigger-disabled state to restore after a merge run
    private Boolean accountTriggerDisabled;
    private Boolean contactTriggerDisabled;

    public MRG_GridAction_BATCH(MRG_Duplicate_SVC.candidateFilter filter, String action){
        this.filter = filter == null ? new MRG_Duplicate_SVC.candidateFilter() : filter;
        this.action = action;
        this.objectType = this.filter.objectType;
        this.ruleName = this.filter.ruleName;
        this.confidenceMin = this.filter.confidenceMin;
        this.confidenceMax = this.filter.confidenceMax;
        this.autoMerge = this.filter.autoMerge;
        this.statuses = this.filter.safeStatuses();
    }

    private Boolean isMergeAction(){
        return action == 'merge' || action == 'mergeAccounts';
    }

    public Database.QueryLocator start(Database.BatchableContext bc){
        if(isMergeAction()){
            MergeControlSettings__c settings = MRG_Merge_SVC.getSettings();
            if(settings != null){
                if(accountTriggerDisabled == null) accountTriggerDisabled = settings.DisableAccountTrigger__c;
                if(contactTriggerDisabled == null) contactTriggerDisabled = settings.DisableContactTrigger__c;
                settings.DisableAccountTrigger__c = true;
                settings.DisableContactTrigger__c = true;
                upsert settings;
            }
        }
        String soqlQuery = MRG_Duplicate_SVC.getMergeCandidateFieldSOQL() + MRG_Duplicate_SVC.getWhereClause(filter);
        return Database.getQueryLocator(soqlQuery);
    }

    public void execute(Database.BatchableContext bc, List<sObject> scope){
        List<MergeCandidate__c> candidates = (List<MergeCandidate__c>) scope;
        if(action == 'remove'){
            for(MergeCandidate__c c:candidates)
                c.NotADuplicate__c = true;
            update candidates;
        } else if(action == 'mergeAccounts'){
            for(MergeCandidate__c c:candidates)
                MRG_AccountMerge_SVC.mergeAccounts(c);
        } else {
            Map<String, List<MergeCandidate__c>> byObject = new Map<String, List<MergeCandidate__c>>();
            for(MergeCandidate__c c:candidates){
                if(!byObject.containsKey(c.Object__c))
                    byObject.put(c.Object__c, new List<MergeCandidate__c>());
                byObject.get(c.Object__c).add(c);
            }
            for(String objType:byObject.keySet())
                MRG_Merge_SVC.processMergesFromBatch(byObject.get(objType), objType, false);
        }
    }

    public void finish(Database.BatchableContext bc){
        if(isMergeAction()){
            MergeControlSettings__c settings = MRG_Merge_SVC.getSettings();
            if(settings != null){
                settings.DisableAccountTrigger__c = accountTriggerDisabled == null ? false : accountTriggerDisabled;
                settings.DisableContactTrigger__c = contactTriggerDisabled == null ? false : contactTriggerDisabled;
                upsert settings;
            }
        }
    }
}
