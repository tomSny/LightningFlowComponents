/**
 * @description       : SendBetterEmailAddTasksToEmail - helper
 * @author            : Mohith Shrivastava
 * @group             : 
 * @last modified on  : 2021-10-05
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



	public static void SaveTasks(SendBetterEmailRequest[] requests) {
		List<TaskWrapper> lstTaskWrapper = new List<TaskWrapper>();
		LIST<SendBetterEmailRequest> recordsToTask = new LIST<SendBetterEmailRequest>();
		LIST<string> allTargetObjectIds = new LIST<string>();
        for (SendBetterEmailRequest sber : requests) {
			if (sber.isValid && sber.response.isSuccess==true && sber.setSaveAsTask) {
				if (sber.emailMessageType == SendBetterEmailConstant.MASSEMAIL) {
					if (sber.targetObjectIds!=null && sber.whatIds!=null) {
						allTargetObjectIds.addAll(sber.targetObjectIds);
					}
				} else {
					if (String.isNotBlank(sber.recordId) && String.isNotBlank(sber.templateTargetObjectId)) {
						allTargetObjectIds.add(sber.templateTargetObjectId);
					}
				}
				recordsToTask.add(sber);
			}
        }
		integer inx = 0; //temp workaround...find a better way
		for (SendBetterEmailRequest sbe : recordsToTask) {
			sbe.index=inx++;
			lstTaskWrapper.addAll(addTasks(sbe, sendBetterEmailUtil.getMapRecordIdByName(allTargetObjectIds) ));
		}


		List<Task> lstTaskToInsert = new List<Task>();
        for (TaskWrapper taskWrap : lstTaskWrapper) {
            lstTaskToInsert.add(taskWrap.taskRec);
        }
        List<Database.SaveResult> taskInsertResults = Database.insert(lstTaskToInsert,false);

        for (integer i = 0; i < taskInsertResults.size(); i++) {
            Database.SaveResult taskResult = taskInsertResults[i];
            TaskWrapper taskWrapper = lstTaskWrapper[i];
            SendBetterEmailResponse response = recordsToTask[taskWrapper.requestIndex].response;
            String taskId = taskResult.getId();
            Task taskRecord = lstTaskToInsert[i];
            if (taskResult.isSuccess()) {
                response.taskIds.add(taskId);
            } else {
                string msg = 'Task Insert failed for RecordId ' + taskRecord.whatId + ' with error ' + sendBetterEmailUtil.getDatabaseErrorString(taskResult.getErrors());
                response.taskErrors.add(msg);
            }
        }
	}

	public static List<TaskWrapper> addTasks(SendBetterEmailRequest request, Map<String, String> mapRecordIdByName) {
		List<String> recipientList;
		LIST<string> allTargetObjectIds = new LIST<string>();
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
	// I NEED YO UNDERSTAND REQUIRMENTS??
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
		List<String> theseTargets = new List<String>{request.templateTargetObjectId };
		List<String> lstWhatIds = new List<String>{ request.recordId };

		if (request.emailMessageType == SendBetterEmailConstant.MASSEMAIL) {
			theseTargets = request.targetObjectIds;
			lstWhatIds = request.whatIds;
		} else {
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