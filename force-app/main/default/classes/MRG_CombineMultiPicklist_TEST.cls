/**
* @author tj@tjgriffin.com
* @group Merge
* @description unit tests for the multipicklist Combine preservation rule helpers
*/
@isTest
private class MRG_CombineMultiPicklist_TEST {

	static testMethod void testCombineUnionsAndDedupes() {
		system.assertEquals('A;B;C', (String) MRG_Merge_SVC.combineMultiPicklist('A;B', 'B;C'),
			'union de-duplicates shared values, preserving order');
	}

	static testMethod void testCombineTrimsAndDropsBlanks() {
		system.assertEquals('A;B;C', (String) MRG_Merge_SVC.combineMultiPicklist(' A ; B ', 'B; C ;'),
			'values are trimmed and empty segments dropped');
	}

	static testMethod void testCombineHandlesNulls() {
		system.assertEquals('A;B', (String) MRG_Merge_SVC.combineMultiPicklist('A;B', null), 'null merge value -> keep value');
		system.assertEquals('X', (String) MRG_Merge_SVC.combineMultiPicklist(null, 'X'), 'null keep value -> merge value');
		system.assertEquals('', (String) MRG_Merge_SVC.combineMultiPicklist(null, null), 'both null -> empty');
	}

	static testMethod void testIsMultiPicklistFalseForOtherTypes() {
		system.assertEquals(false, MRG_Merge_SVC.isMultiPicklist('Contact', 'Email'), 'Email is not a multipicklist');
		system.assertEquals(false, MRG_Merge_SVC.isMultiPicklist('Contact', 'NoSuchField__x'), 'unknown field -> false');
		system.assertEquals(false, MRG_Merge_SVC.isMultiPicklist('NoSuchObject__x', 'Email'), 'unknown object -> false');
		system.assertEquals(false, MRG_Merge_SVC.isMultiPicklist('Contact', ''), 'blank field -> false');
	}
}
