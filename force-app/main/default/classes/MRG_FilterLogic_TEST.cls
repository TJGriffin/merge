/**
* @author tj@tjgriffin.com
* @group Merge
* @description unit tests for the pure filter-logic parser/evaluator
*/
@isTest
private class MRG_FilterLogic_TEST {

	private static Map<Integer, Boolean> results(Boolean one, Boolean two, Boolean three) {
		return new Map<Integer, Boolean>{ 1 => one, 2 => two, 3 => three };
	}

	static testMethod void testBlankLogicAndsAll() {
		system.assert(MRG_FilterLogic.evaluate('', new Map<Integer, Boolean>{1=>true, 2=>true}), 'all true -> true');
		system.assert(!MRG_FilterLogic.evaluate(null, new Map<Integer, Boolean>{1=>true, 2=>false}), 'one false -> false');
		system.assert(MRG_FilterLogic.evaluate('', new Map<Integer, Boolean>()), 'empty -> vacuously true');
	}

	static testMethod void testSimpleAnd() {
		system.assert(MRG_FilterLogic.evaluate('1 AND 2', results(true, true, false)));
		system.assert(!MRG_FilterLogic.evaluate('1 AND 2', results(true, false, false)));
	}

	static testMethod void testSimpleOr() {
		system.assert(MRG_FilterLogic.evaluate('1 OR 2', results(false, true, false)));
		system.assert(!MRG_FilterLogic.evaluate('1 OR 2', results(false, false, false)));
	}

	static testMethod void testPrecedenceAndBindsTighterThanOr() {
		// 1 OR 2 AND 3  ==  1 OR (2 AND 3)
		system.assert(MRG_FilterLogic.evaluate('1 OR 2 AND 3', results(true, false, false)), '1 true -> true');
		system.assert(!MRG_FilterLogic.evaluate('1 OR 2 AND 3', results(false, true, false)), '2 AND 3 false, 1 false -> false');
		system.assert(MRG_FilterLogic.evaluate('1 OR 2 AND 3', results(false, true, true)), '2 AND 3 true -> true');
	}

	static testMethod void testParentheticalGrouping() {
		// (1 AND 2) OR 3
		system.assert(MRG_FilterLogic.evaluate('(1 AND 2) OR 3', results(true, true, false)), '1 AND 2 -> true');
		system.assert(MRG_FilterLogic.evaluate('(1 AND 2) OR 3', results(false, false, true)), '3 -> true');
		system.assert(!MRG_FilterLogic.evaluate('(1 AND 2) OR 3', results(true, false, false)), 'neither group -> false');
	}

	static testMethod void testNestedParentheses() {
		// ((1 OR 2) AND 3)
		system.assert(MRG_FilterLogic.evaluate('((1 OR 2) AND 3)', results(true, false, true)));
		system.assert(!MRG_FilterLogic.evaluate('((1 OR 2) AND 3)', results(true, false, false)), '3 false -> false');
	}

	static testMethod void testCaseInsensitiveOperators() {
		system.assert(MRG_FilterLogic.evaluate('1 and 2 or 3', results(true, true, false)));
	}

	static testMethod void testMissingConditionTreatedAsFalse() {
		// references condition 3 but map has no entry -> false
		system.assert(!MRG_FilterLogic.evaluate('3', new Map<Integer, Boolean>{1=>true}));
	}

	static testMethod void testTokenize() {
		List<String> tokens = MRG_FilterLogic.tokenize('(1 AND 2) OR 3');
		system.assertEquals(new List<String>{'(', '1', 'AND', '2', ')', 'OR', '3'}, tokens);
	}

	static testMethod void testParseErrors() {
		assertParseError('1 AND', 'trailing operator with no operand');
		assertParseError('(1 AND 2', 'missing closing paren');
		assertParseError('1 2', 'two operands no operator');
		assertParseError('1 AND $', 'bad token');
		assertParseError('AND 1', 'leading operator');
	}

	static testMethod void testValidateRange() {
		MRG_FilterLogic.validate('(1 AND 2) OR 3', 3); // ok, no throw
		Boolean threw = false;
		try {
			MRG_FilterLogic.validate('1 AND 4', 3);
		} catch(MRG_FilterLogic.ParseException e) {
			threw = true;
		}
		system.assert(threw, 'referencing out-of-range condition should throw');
	}

	private static void assertParseError(String logic, String why) {
		Boolean threw = false;
		try {
			MRG_FilterLogic.evaluate(logic, new Map<Integer, Boolean>{1=>true, 2=>true});
		} catch(MRG_FilterLogic.ParseException e) {
			threw = true;
		}
		system.assert(threw, 'expected parse error: ' + why);
	}
}
