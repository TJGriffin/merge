@isTest
private class CON_DupeSettings_TEST {

    static testMethod void runTest() {
        CON_Duplicate_SVC.dupeRule dupeRule = new CON_Duplicate_SVC.dupeRule();
        dupeRule.name = 'DRTEST';
        dupeRule.ruleName='DRTEST';
        dupeRule.objectType='Contact';
        dupeRule.autoMerge = true;

        CON_Duplicate_SVC.duplicateRuleSettings = new List<CON_Dupicate_SVC.dupeRule>();
        CON_Duplicate_SVC.duplicateRuleSettings.add(dupeRule);
        List<CON_Duplicate_SVC.dupeRule> dupeRulesFromCon =  CON_DupeSettings_CTRL.getActiveDuplicateRules();
        dupeRulesFromCon =  CON_DupeSettings_CTRL.getDuplicateRuleSettings();
        system.assert(dupeRulesFromCon.size()>0);
        

        CON_DupeSettings_CTRL.saveDuplicateRuleSettings(JSON.serialize(dupeRulesFromCon));
    }
}
