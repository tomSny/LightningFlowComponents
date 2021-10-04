/**
 * @description       : SendBetterEmailAddTasksToEmail - helper
 * @author            : Mohith Shrivastava
 * @group             : 
 * @last modified on  : 2021-10-03
 * @last modified by  : Tom Snyder <tom@3ddd.com>
 * Modifications Log 
 * Ver		Date		Author				Modification
 * 2.00.02	10-12-2020	Mohith Shrivastava	Initial Version - separated and refactored 
**/
public inherited sharing class SendBetterEmailAddTasksToEmail {


/*
	
	// Add task activities
	public static List<TaskWrapper> addTasks(SendBetterEmailRequest request) {
		//List<String> recipientList,
		//Map<Id, EmailTemplate> mapIdByEmailTemplate,
		//Map<String, String> mapRecordIdByName
	//) {
		List<String> thisResultIds = new List<String>();
		String recipientListIds;

		//JACK: how to handle: legacy logic! what if subject has a mergefield?  also subject was never queried so was no working as logic intended
		string subject = (request?.EmailTemplate?.Subject==null ) ? request.subject : request.EmailTemplate.Subject;
*/		
		/* --- OLD
		IF(request?.EmailTemplate?.Subject!=null )
		if (
			request.templateID != null &&
			subject == null &&
			mapIdByEmailTemplate.get(request.templateID) != null
		) {
			subject = mapIdByEmailTemplate.get(request.templateID).subject;
		}
		*/

	
	/**
	* @description new definition for AddTask
	* @author Tom Snyder <tom@3ddd.com> | 2021-10-03 
	* @param request 
	* @param mapRecordIdByName 
	* @return List<TaskWrapper> 
	**/
	public static List<TaskWrapper> addTasks(SendBetterEmailRequest request,Map<String, String> mapRecordIdByName) {
		List<String> recipientList;
		if ( request.emailMessageType != SendBetterEmailConstant.MASSEMAIL) {
			recipientList.addall(request.toAddresses);
			recipientList.addall(request.ccAddresses);
			recipientList.addall(request.bccAddresses);
		}
		Map<Id, EmailTemplate> mapIdByEmailTemplate = new Map<Id, EmailTemplate>();
		if (request.emailTemplate!=null) {
			mapIdByEmailTemplate.put(request.TemplateID, request.emailTemplate);
		}
		return addTasks(request, recipientList, mapIdByEmailTemplate, mapRecordIdByName);
	}

	
	// Add task activities
	// NEED YO UNDERSTAND REQUIRMENTS??
	//ONLY SUCCESSFUL EMAILS?  
	//		//JACK: how to handle: legacy logic! what if subject has a mergefield?  also subject was never queried so was no working as logic intended
	public static List<TaskWrapper> addTasks(
		SendBetterEmailRequest request,
		List<String> recipientList,
		Map<Id, EmailTemplate> mapIdByEmailTemplate,
		Map<String, String> mapRecordIdByName
	) {
		List<String> thisResultIds = new List<String>();
		String recipientListIds;
		string subject = request.subject;
		if (
			request.templateID != null &&
			subject == null &&
			mapIdByEmailTemplate.get(request.templateID) != null
		) {
			subject = mapIdByEmailTemplate.get(request.templateID).subject;
		}

		List<TaskWrapper> lstTaskWrapper = new List<TaskWrapper>();

		List<String> theseTargets = new List<String>{
			request.templateTargetObjectId
		};
		List<String> lstWhatIds = new List<String>{ request.recordId };

		if (request.emailMessageType == SendBetterEmailConstant.MASSEMAIL) {
			theseTargets = request.targetObjectIds;
			lstWhatIds = request.whatIds;
		} else {
			theseTargets = request.templateTargetObjectId == null
				? new List<String>()
				: new List<String>{ request.templateTargetObjectId };
			lstWhatIds = request.recordId == null
				? new List<String>()
				: new List<String>{ request.recordId };
			Integer j = 0;
			while (j < recipientList.size()) {
				if (String.isBlank(recipientList[j])) {
					recipientList.remove(j);
				} else {
					j++;
				}
			}
		}
		for (integer i = 0; i < lstWhatIds.size(); i++) {
			string thisRecipient;
			if (request.emailMessageType == SendBetterEmailConstant.MASSEMAIL) {
				if (mapRecordIdByName.get(lstWhatIds[i]) != null) {
					thisRecipient = mapRecordIdByName.get(lstWhatIds[i]);
				}
			} else {
				if (mapRecordIdByName.get(lstWhatIds[i]) != null) {
					thisRecipient = theseTargets.isEmpty()
						? string.join(recipientList, ',')
						: mapRecordIdByName.get(lstWhatIds[i]);
				}
			}
			TaskWrapper taskWrapper = new TaskWrapper();
			Task task = new Task(
				OwnerId = UserInfo.getUserId(),
				Subject = 'Sent Email: ' + subject,
				Description = 'Sent Email : ' +
					subject +
					' to recipient(s): ' +
					thisRecipient,
				Status = 'Closed',
				Priority = 'Normal',
				ActivityDate = Date.today(),
				WhatId = lstWhatIds[i]
			);
			taskWrapper.requestIndex = request.index;
			taskWrapper.taskRec = task;
			lstTaskWrapper.add(taskWrapper);
		}

		return lstTaskWrapper;
	}

	public inherited sharing class TaskWrapper {
		public Integer requestIndex; // Request Number
		public Task taskRec; //  Task Record Instance
	}
}