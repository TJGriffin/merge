/**
* @author tj@tjgriffin.com
* @group Merge
* @description tests for the text-length (Longest/Shortest) and Has-a-Value (Populated) preservation
* rules. testValue returns true when the merge (losing) value should be kept over the surviving value.
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

	static testMethod void testPopulated() {
		system.assert(MRG_Merge_SVC.testValue('x', '', 'Populated', false), 'take the merge value when the kept value is blank');
		system.assert(!MRG_Merge_SVC.testValue('x', 'y', 'Populated', false), 'keep the surviving value when it is populated');
		system.assert(!MRG_Merge_SVC.testValue('', 'y', 'Populated', false), 'do not overwrite a populated value with a blank');
		system.assert(MRG_Merge_SVC.testValue('x', null, 'Populated', false), 'a null kept value always takes the merge value');
	}
}
