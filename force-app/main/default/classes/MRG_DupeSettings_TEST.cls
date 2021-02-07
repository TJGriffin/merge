@isTest
private class MRG_DupeSettings_TEST {

    static testMethod void runTest() {
        MRG_Duplicate_SVC.dupeRule dupeRule = new MRG_Duplicate_SVC.dupeRule();
        dupeRule.name = 'DRTEST';
        dupeRule.ruleName='DRTEST';
        dupeRule.objectType='Contact';
        dupeRule.autoMerge = true;

        MRG_Duplicate_SVC.duplicateRuleSettings = new List<MRG_Duplicate_SVC.dupeRule>();
        MRG_Duplicate_SVC.duplicateRuleSettings.add(dupeRule);
        List<MRG_Duplicate_SVC.dupeRule> dupeRulesFromCon =  MRG_DupeSettings_CTRL.getActiveDuplicateRules();
        dupeRulesFromCon =  MRG_DupeSettings_CTRL.getDuplicateRuleSettings();
        system.assert(dupeRulesFromCon.size()>0);
        

        MRG_DupeSettings_CTRL.saveDuplicateRuleSettings(JSON.serialize(dupeRulesFromCon));
    }
}
