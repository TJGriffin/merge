/**
* @author tj@tjgriffin.com
* @date 2023
* @group Merge
* @description Service for managing and processing keep rules
*/
public with sharing class MRG_KeepRule_SVC {

    public List<MergeCandidate__c> mergeCandidates;

    public List<keepRule> keepRules;


	/*******************************************************************************************************
	* @description constructor
	*/	
    public MRG_KeepRule_SVC() {
        getRules();
    }

	/*******************************************************************************************************
	* @description overridden constructor
	*/	
    public MRG_KeepRule_SVC(List<MergeCandidate__c> mergeCandidates) {
        this.mergeCandidates = mergeCandidates;
        getRules();
        processCandidates();
    }

	/*******************************************************************************************************
	* @description overridden constructor
	*/	
    private void getRules(){

    }

	/*******************************************************************************************************
	* @description overridden constructor
	*/	
    private void processCandidates(){

    }

	/*******************************************************************************************************
	* @description duplicate rule
	*/ 
    public class keepRule {
        @auraEnabled
        public String objectType;

        @auraEnabled 
        public String name;

        @auraEnabled
        public Boolean enabled;

        @auraEnabled
        public List<keepFieldRule> rules;

    }
	/*******************************************************************************************************
	* @description duplicate rule
	*/ 
    public class keepFieldRule {
        @auraEnabled
        public keepRule rule;

        @auraEnabled
        public String fieldName;

        @auraEnabled
        public String ruleType;

        @auraEnabled
        public String ruleValue;

        @auraEnabled
        public String scoreValue;
    }
}