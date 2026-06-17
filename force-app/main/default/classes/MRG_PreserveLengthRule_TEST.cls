/**
* @author tj@tjgriffin.com
* @group Merge
* @description tests for the text-length (Longest/Shortest) and Contains-substring preservation rules.
* testValue returns true when the merge (losing) value should be kept over the surviving value.
*/
@isTest
private class MRG_PreserveLengthRule_TEST {

	static testMethod void testLongest() {
		system.assert(MRG_Merge_SVC.testValue('abcd', 'ab', 'Longest', false), 'longer merge value should win');
		system.assert(!MRG_Merge_SVC.testValue('a', 'abc', 'Longest', false), 'shorter merge value should not win');
		system.assert(!MRG_Merge_SVC.testValue('ab', 'ab', 'Longest', false), 'equal length keeps the surviving value');
	}

	static testMethod void testShortest() {
		system.assert(MRG_Merge_SVC.testValue('a', 'abc', 'Shortest', false), 'shorter merge value should win');
		system.assert(!MRG_Merge_SVC.testValue('abcd', 'ab', 'Shortest', false), 'longer merge value should not win');
		system.assert(!MRG_Merge_SVC.testValue('', 'abc', 'Shortest', false), 'a blank merge value never wins shortest');
	}

	static testMethod void testContains() {
		// take the merge value only when it contains the substring and the kept value does not
		system.assert(MRG_Merge_SVC.testValue('has VIP tag', 'plain', 'Contains', false, 'VIP'), 'merge contains substring, keep does not -> take merge');
		system.assert(!MRG_Merge_SVC.testValue('plain', 'has VIP tag', 'Contains', false, 'VIP'), 'keep contains substring, merge does not -> keep surviving');
		system.assert(!MRG_Merge_SVC.testValue('VIP a', 'VIP b', 'Contains', false, 'VIP'), 'both contain -> keep the surviving value');
		system.assert(!MRG_Merge_SVC.testValue('x', 'y', 'Contains', false, null), 'no configured substring -> no change');
		system.assert(MRG_Merge_SVC.testValue('VIP', null, 'Contains', false, 'VIP'), 'a null kept value always takes the merge value');
	}
}
