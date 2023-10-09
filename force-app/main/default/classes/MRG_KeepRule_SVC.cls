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
        List<keepRule> rules = new List<keepRule>();
        Map<String, List<KeepFieldRule__mdt>> fieldRulesByRuleName = new Map<String, List<KeepFieldRule__mdt>>();
        for(KeepFieldRule__mdt kfr:KeepFieldRule__mdt.getAll().values()){
            String ruleName = kfr.KeepRule__r.QualifiedAPIName;
            if(!fieldRulesByRuleName.containsKey(ruleName)){
                fieldRulesByRuleName.put(ruleName,new List<KeepFieldRule__mdt>());
            }
            fieldRulesByRuleName.get(ruleName).add(kfr);
        }

        for(KeepRuleSetting__mdt kr:KeepRuleSetting__mdt.getAll().values()){
            List<KeepFieldRule__mdt> kfrs = fieldRulesByRuleName.containsKey(kr.QualifiedAPINAme) ? fieldRulesByRuleName.get(kr.QualifiedAPIName) : new List<KeepFieldRule__mdt>();
            rules.add(new keepRule(kr, kfrs));
        }

        this.keepRules = rules;
    }

	/*******************************************************************************************************
	* @description overridden constructor
	*/	
    private void processCandidates(){

    }

	/*******************************************************************************************************
	* @description duplicate rule
    * @param keepRule the rule to return metadata records for
	*/
    public KeepRuleSetting__mdt getKeepRuleMetadataFromObject(keepRule keepRuleObject){
        KeepRuleSetting__mdt keepRuleSetting = new KeepRuleSetting__mdt(
            Label = keepRuleObject.label,
            Disable__c = keepRuleObject.disabled
        );
        String qualifiedName = String.isBlank(keepRuleObject.name) ? keepRuleObject.label.replace('_','').replace(' ','') : keepRuleObject.name;
        keepRuleSetting.qualifiedAPIName = qualifiedName;

        Map<String, Object> keepRuleJSON = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(keepRuleSetting));
		Map<String, Object> objField = new Map<String, Object> {
            'attributes' => new Map<String, Object> {
                'type' => 'EntityDefinition'
            },
            'QualifiedAPIName' => keepRuleObject.objectType 
		};
        keepRuleJSON.put('Object__r',objField);
        keepRuleSetting = (KeepRuleSetting__mdt) JSON.deserialize(JSON.serialize(keepRuleJSON),KeepRuleSetting__mdt.class);
        return keepRuleSetting;
    }

	/*******************************************************************************************************
	* @description duplicate rule
    * @param keepRule the rule to return metadata records for
	*/
    public KeepFieldRule__mdt getKeepRuleMetadataFromObject(keepFieldRule kfr){
        KeepFieldRule__mdt keepFieldRuleSetting = new KeepFieldRule__mdt(
            Disable__c = kfr.disabled,
            Rule_Type__c = kfr.ruleType,
            Score__c = kfr.scoreValue,
            ObjectValue__c = kfr.ruleValue
        );
        String label = String.isBlank(kfr.label) ? kfr.fieldName : kfr.label;

        String qualifiedName = String.isBlank(kfr.name) ? kfr.label.replace('_','').replace(' ','') : kfr.name;
        keepFieldRuleSetting.qualifiedAPIName = qualifiedName;

        Map<String, Object> keepFieldRuleSettingJSON = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(keepFieldRuleSetting));
		Map<String, Object> objField = new Map<String, Object> {
			'attributes' => new Map<String, Object> {
				'type' => 'EntityDefinition'
			},
			'QualifiedAPIName' => kfr.objectType
		};
        keepFieldRuleSettingJSON.put('Object__r',objField);

        Map<String, Object> fldField = new Map<String, Object>{
            'attributes' => new Map<String, Object> {
                'type' => 'EntityParticle'
            },
            'QualifiedAPIName' => kfr.fieldName  
        };
        keepFieldRuleSettingJSON.put('Field__r',fldField);

        Map<String, Object> ruleField = new Map<String, Object>{
            'attributes' => new Map<String, Object> {
                'type' => 'EntityDefinition'
            },
            'QualifiedAPIName' => kfr.ruleName 
        };
        keepFieldRuleSettingJSON.put('KeepRule__r',ruleField);

        keepFieldRuleSetting = (KeepFieldRule__mdt) JSON.deserialize(JSON.serialize(keepFieldRuleSettingJSON),KeepFieldRule__mdt.class);
        return keepFieldRuleSetting;
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
        public String label;

        @auraEnabled
        public Boolean disabled;

        @auraEnabled
        public List<keepFieldRule> rules;


        public keepRule(KeepRuleSetting__mdt keepRuleMD, List<KeepFieldRule__mdt> keepFieldRules){
            this.objectType = keepRuleMD.Object__r.QualifiedAPIName;
            this.name = keepRuleMD.QualifiedAPIName;
            this.label = keepRuleMD.label;
            this.disabled = keepRuleMD.Disable__c;
            List<keepFieldRule> fieldRules = new List<keepFieldRule>();
            for(KeepFieldRule__mdt kfr:keepFieldRules){
                keepFieldRule fieldrule = new keepFieldRule(kfr);
                fieldRules.add(fieldRule);
            }
            this.rules = fieldRules;

        }

    }
	/*******************************************************************************************************
	* @description duplicate rule
	*/ 
    public class keepFieldRule {
        @auraEnabled
        public String label;

        @auraEnabled
        public String name;

        @auraEnabled
        public String ruleName;

        @auraEnabled
        public String fieldName;

        @auraEnabled
        public String objectType;

        @auraEnabled
        public String ruleType;

        @auraEnabled
        public String ruleValue;

        @auraEnabled
        public Integer scoreValue;

        @auraEnabled
        public Boolean disabled;

        public keepFieldRule(KeepFieldRule__mdt fieldRule){
            this.ruleName = fieldRule.KeepRule__r.QualifiedAPIName; 
            this.objectType =  fieldRule.Object__r.QualifiedAPIName;
            this.fieldName = fieldRule.Field__r.QualifiedAPIName;
            this.ruleType = fieldRule.Rule_Type__c;
            this.ruleValue = fieldRule.ObjectValue__c;
            this.scoreValue = Integer.valueOf(fieldRule.Score__c);     
        }
    }
}