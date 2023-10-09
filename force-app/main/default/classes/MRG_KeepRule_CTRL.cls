public with sharing class MRG_KeepRule_CTRL {

    @auraEnabled(cacheable=true)
    public static List<MRG_KeepRule_SVC.keepRule> getRules(){
        return new List<MRG_KeepRule_SVC.keepRule>();
    }

    @auraEnabled
    public static void saveRules(List<MRG_KeepRule_SVC.keepRule> rules){

    }
}