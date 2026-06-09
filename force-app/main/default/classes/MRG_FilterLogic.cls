/**
* @author tj@tjgriffin.com
* @group Merge
* @description evaluates report-style filter logic strings such as "(1 AND 2) OR 3" against a map of
* numbered condition results. Pure and stateless: no SObjects, no DML, no SOQL. Supports AND, OR,
* and parenthetical grouping with standard precedence (parentheses, then AND, then OR).
*
* If the logic string is blank, all referenced conditions are AND-ed together by the caller's map.
*/
public with sharing class MRG_FilterLogic {

	/*******************************************************************************************************
	* @description thrown when a filter logic string cannot be parsed
	*/
	public class ParseException extends Exception {}

	/*******************************************************************************************************
	* @description evaluates a filter logic string against condition results
	* @param filterLogic e.g. "(1 AND 2) OR 3"; when blank, all results are AND-ed together
	* @param conditionResults a map of condition number (1-based) to its boolean result
	* @return Boolean the overall result
	*/
	public static Boolean evaluate(String filterLogic, Map<Integer, Boolean> conditionResults) {
		if(String.isBlank(filterLogic))
			return evaluateAllAnd(conditionResults);
		List<String> tokens = tokenize(filterLogic);
		Parser parser = new Parser(tokens, conditionResults);
		Boolean result = parser.parseExpression();
		parser.expectEnd();
		return result;
	}

	/*******************************************************************************************************
	* @description validates that a filter logic string parses and only references condition numbers in
	* the allowed range [1, conditionCount]. Throws ParseException on any problem.
	* @param filterLogic the logic string
	* @param conditionCount the number of available conditions
	*/
	public static void validate(String filterLogic, Integer conditionCount) {
		if(String.isBlank(filterLogic))
			return;
		Map<Integer, Boolean> dummy = new Map<Integer, Boolean>();
		for(Integer i=1; i<=conditionCount; i++)
			dummy.put(i, true);
		List<String> tokens = tokenize(filterLogic);
		// verify every referenced number is in range
		for(String token:tokens) {
			if(token.isNumeric()) {
				Integer n = Integer.valueOf(token);
				if(n < 1 || n > conditionCount)
					throw new ParseException('Filter logic references condition ' + n + ' which is out of range 1-' + conditionCount);
			}
		}
		Parser parser = new Parser(tokens, dummy);
		parser.parseExpression();
		parser.expectEnd();
	}

	/*******************************************************************************************************
	* @description ANDs all condition results together (the default when no logic string is supplied)
	* @param conditionResults the condition results
	* @return Boolean true when every result is true (vacuously true when empty)
	*/
	private static Boolean evaluateAllAnd(Map<Integer, Boolean> conditionResults) {
		for(Boolean result:conditionResults.values()) {
			if(result != true)
				return false;
		}
		return true;
	}

	/*******************************************************************************************************
	* @description splits a filter logic string into tokens: numbers, AND, OR, '(' and ')'
	* @param filterLogic the logic string
	* @return List<String> the tokens
	*/
	@testvisible
	private static List<String> tokenize(String filterLogic) {
		List<String> tokens = new List<String>();
		// pad parentheses so a simple whitespace split separates them from operands
		String spaced = filterLogic.replace('(', ' ( ').replace(')', ' ) ');
		for(String raw:spaced.split('\\s+')) {
			String token = raw.trim();
			if(String.isBlank(token))
				continue;
			String upper = token.toUpperCase();
			if(upper == 'AND' || upper == 'OR' || token == '(' || token == ')') {
				tokens.add(token == '(' || token == ')' ? token : upper);
			} else if(token.isNumeric()) {
				tokens.add(token);
			} else {
				throw new ParseException('Unexpected token in filter logic: "' + token + '"');
			}
		}
		return tokens;
	}

	/*******************************************************************************************************
	* @description recursive-descent parser/evaluator. Grammar (lowest to highest precedence):
	*   expression := andTerm ( OR andTerm )*
	*   andTerm    := factor ( AND factor )*
	*   factor     := '(' expression ')' | number
	* Evaluation happens inline against the supplied condition results.
	*/
	private class Parser {
		private final List<String> tokens;
		private final Map<Integer, Boolean> conditionResults;
		private Integer pos;

		public Parser(List<String> tokens, Map<Integer, Boolean> conditionResults) {
			this.tokens = tokens;
			this.conditionResults = conditionResults;
			this.pos = 0;
		}

		public Boolean parseExpression() {
			Boolean value = parseAndTerm();
			while(peek() == 'OR') {
				consume();
				Boolean right = parseAndTerm();
				value = value || right;
			}
			return value;
		}

		private Boolean parseAndTerm() {
			Boolean value = parseFactor();
			while(peek() == 'AND') {
				consume();
				Boolean right = parseFactor();
				value = value && right;
			}
			return value;
		}

		private Boolean parseFactor() {
			String token = peek();
			if(token == null)
				throw new ParseException('Unexpected end of filter logic');
			if(token == '(') {
				consume();
				Boolean value = parseExpression();
				if(peek() != ')')
					throw new ParseException('Missing closing parenthesis in filter logic');
				consume();
				return value;
			}
			if(token.isNumeric()) {
				consume();
				Integer n = Integer.valueOf(token);
				Boolean result = conditionResults.get(n);
				return result == true;
			}
			throw new ParseException('Unexpected token "' + token + '" in filter logic');
		}

		public void expectEnd() {
			if(pos < tokens.size())
				throw new ParseException('Unexpected trailing token "' + tokens[pos] + '" in filter logic');
		}

		private String peek() {
			return pos < tokens.size() ? tokens[pos] : null;
		}

		private void consume() {
			pos++;
		}
	}
}
