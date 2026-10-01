/**
* @author tj@tjgriffin.com
* @group Merge
* @description Service for the optional NPSP integration. NPSP is reached only through its
* System.Callable API resolved by name at runtime, so this package compiles and runs in orgs
* without NPSP installed.
*/
public with sharing class MRG_Npsp_SVC {

	public static final String ACTION_DISABLE_ALL_TRIGGERS = 'TDTM.DisableAllTriggers';

	/*******************************************************************************************************
	* @description the NPSP Callable API, or null when NPSP is not installed. Tests inject a mock.
	*/
	@TestVisible private static System.Callable npspApi {
		get {
			if(npspApi == null) {
				Type apiType = Type.forName('npsp', 'Callable_API');
				npspApi = apiType != null ? (System.Callable) apiType.newInstance() : null;
			}
			return npspApi;
		}
		set;
	}

	/*******************************************************************************************************
	* @description whether NPSP is installed in this org
	* @return Boolean
	*/
	public static Boolean isInstalled() {
		return npspApi != null;
	}

	/*******************************************************************************************************
	* @description disables the NPSP (TDTM) triggers for the rest of the current transaction through the
	* NPSP trigger config API. The Trigger Handler records are not changed, so other transactions are
	* unaffected. Does nothing when NPSP is not installed.
	* @return Boolean true when the triggers were disabled, false when NPSP is not installed
	*/
	public static Boolean disableTriggers() {
		if(!isInstalled())
			return false;
		npspApi.call(ACTION_DISABLE_ALL_TRIGGERS, new Map<String, Object>());
		return true;
	}
}
