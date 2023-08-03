/**
* @author tj@tjgriffin.com
* @date 2023
* @group Duplicate
* @description controller for batch jobs
*/
public with sharing class MRG_BatchControl_CTRL {
	/*******************************************************************************************************
	* @description gets the list of jobs currently scheduled
	* @return List<dupeRule>
	*/	
	@auraEnabled
	public static void runScan(){
		database.executeBatch(new MRG_DuplicateScan_BATCH(),50);
	}

	/*******************************************************************************************************
	* @description gets the list of jobs currently scheduled
	* @return List<dupeRule>
	*/	
	@auraEnabled
	public static void runAutoMerge(){
		database.executeBatch(new MRG_DuplicateMerge_BATCH(),1);
	}

	/*******************************************************************************************************
	* @description gets the list of jobs currently scheduled
	* @return List<dupeRule>
	*/	
	@AuraEnabled
	public static MRG_BatchControl_SVC.scheduledJob scheduleJob(String jobName, String frequency){
		String cronString = String.isNotBlank(frequency) && MRG_BatchControl_SVC.jobScheduleFrequencies.containsKey(frequency) ? MRG_BatchControl_SVC.jobScheduleFrequencies.get(frequency) : '0 0 2 * * 1';

		if(jobName.containsIgnoreCase('scan')){
			System.schedule(jobName,cronString, new MRG_DuplicateScan_BATCH());
		} else {
			System.schedule(jobName,cronString, new MRG_DuplicateMerge_BATCH());
		}

		MRG_BatchControl_SVC.scheduledJob schedJob = new MRG_BatchControl_SVC.scheduledJob();
		schedJob.jobName = jobName;
		schedJob.isActive = true;

		return schedJob;
	}


	/*******************************************************************************************************
	* @description gets the list of jobs currently scheduled
	* @return List<dupeRule>
	*/	
    @AuraEnabled(cacheable=true)
    public static List<MRG_BatchControl_SVC.scheduledJob> getScheduledJobs() {
        return MRG_BatchControl_SVC.getScheduledJobs();

    }




}