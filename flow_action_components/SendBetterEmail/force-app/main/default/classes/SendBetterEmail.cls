/**
 * @File Name			: SendBetterEmail.cls
 * @Description			: Uses Spring/Summer '20 EmailTemplate Object + ContentVersion with multi-lingual
 * @OriginalAuthor		: Alex Edelstein, etal
 * @Group				: unofficialSF
 * @Last Modified By	: Tom Snyder <tom@3ddd.com>
 * @Last Modified On	: 2021-10-06
 * @License				: LICENSE found in https://github.com/alexed1/LightningFlowComponents
 * @Modification Log	:
 *
 * Ver		Date		Author					Modification
 * 0.01					Alex Edelstein			Original Author
 * 1.32		2/5/2020	Jack Pond				Modified for multi-lingual and to throw InvocableActionException on exceptions
 * 1.32		2/11/2020	Alex Edelstein			Bulkified and Changed recordId to String
 * 1.33		3/22/2020	Jack Pond				Added consistency checks, modified Labels and alphabetized params
 * 1.33.1	4/11/2020	Jack Pond				Issues 308,316
 * 1.33.2	5/29/2020	Jack Pond				Version 1.33.2 upgrade - Issues #320,#351,#354, #355, #392
 * 1.33.2	8/02/2020	Jack Pond				Finalized MassEmail and added Tests and Issue #378
 * 2.00.00	8/02/2020	Jack Pond, Mohith		SendBetterEmail - Optimize Bulkification #445
 * 2.00.02	8/15/2020	Jack Pond, Mohith		Modified for coverage testing
 * 2.00.02	8/16/2020	Jack Pond				Corrected singleEmail recipient name for templateTargetId
 * 2.00.02	10-06-2020	Jack Pond				Reverted naming, fixed bugs
 * 2.00.03  11-28-2020  Jack Pond               Updated for Flow Action BasePack and Flow Screen Component Base Pack.
 * 2.00.05  11-28-2020  Jack Pond               Added setTreatTargetObjectAsRecipient Fix: #586
 * 2.00.05  02-15-2021  Jack Pond               ReplyEmail with SendBetterEmail #595
 * 2.01.02  2021-06-11  Jack Pond               Modified so that all checks for null also check for .length() > 0 #702
 * 2.01.05  2021-06-29  Jack Pond               Pasted Typo fix #797 for null pointer exception
 * 2.01.06	2021-07-30	Jack D. Pond		    Fix remainder of checkboxes default/save Fix: #702,#831,#785,#829
						sahib-gadzhiev		    Quick Choice and Flow Combobox Bugs from JET BI Fix: #823
 * 2.01.07  2021-06-29  Jack Pond               Added to Email Category for flow builder New Action
 *
 
* 2.2?.??  2021-10-04  Tom Snyder               large refactor
, here are the main differences:

    - state info is stored on SendBetterEmailRequest (i.e. response, results, emailtemplate, contentVersions, etc..)
    - SendBetterEmailRequest also acts as a builder for MassEmail, SingleEmail, And Task(s);
    - New set of core classes to keep logic modular / SoC.

==========================================================================================
 "Notation" = | ::class:: | method() | { block } | --DataFlowType--> | ""label" |
============================================================================================
    "FLOW_INTERVIEW" --SendBetterEmailRequest[]--> ::SendBetterEmailDispatcher:: {
        Validate() {
            Normalize()-->::EmailTemplateSelector::--setTemplate()--
            -->::AttachmentSelector::--setAttachments()-->validate()
        }
        Dispatch() {
            "MassEmails" --SendBetterEmailRequest[]-->::SendBetterEmailTransmitter::--Send();
            "SingleEmail" --SendBetterEmailRequest[]-->::SendBetterEmailTransmitter::--Send();

            "AddTasks" = SendBetterEmailTransmitter[]-->::PostEmailHandler::--Save();  //TODO
        }
============================================================================================
 * 

 **/

public without sharing class SendBetterEmail {


    //stop unit test failures in sandboxes when email is disabled
    @TestVisible
    static boolean haltSendEmail = ( Test.isRunningTest() && !SendBetterEmail.isEmailDeliverabilityEnabled  );




    // System.debug(SendBetterEmail.isEmailDeliveryEnabled);
    public static boolean isEmailDeliverabilityEnabled {
        get {
            try {
                Messaging.reserveSingleEmailCapacity(1);
                Messaging.reserveMassEmailCapacity(1);
                return true;
            } catch (System.NoAccessException e) {
                return false;
            } catch (Exception ex) {
                //JACK: Want me to throw this error? You have hit EmailCapacity: System.HandledException: The daily limit for the org would be exceeded by this request.
                /*throw new InvocableActionException(
                   ...
                );*/
                return true;
            }
        }
    }



    public class SendBetterEmailDispatcher {
        List<SendBetterEmailRequest> emails;
        //MAP<string,MAP<string,EmailTemplate>> mapTemplatebyNameAndLang;
        double percentValid = 0;


        public SendBetterEmailDispatcher(List<SendBetterEmailRequest> sbes) {
            this.emails = sbes;
        }

        //using Id or Name or Name/lang
        private boolean validate() {
            boolean rtn=true;
            integer errCount = 0;
            EmailTemplateSelector etS = new EmailTemplateSelector(emails);
            AttachmentSelector attS = new AttachmentSelector(emails);
            
            for (SendBetterEmailRequest sbe :  emails) {
                NormalizeSbe(sbe);
                etS.setTemplate(sbe);
                attS.setAttachments(sbe);
                if (!validateSbe(sbe)) {
                    rtn=false;
                    errCount++;
                }
            }
            percentValid = (emails.size()> 0) ? (errCount/emails.size()) : 0;
            return rtn;
        }

        public void dispatch() {
            SendBetterEmailTransmitter massTransmit = getValidMassEmailRequests().send();
            SendBetterEmailTransmitter singleTransmit = getValidSingleEmailRequests().send();
            
            SendBetterEmailAddTasksToEmail.SaveTasks(emails);

            //sbe.setSaveAsTask
        }

        //Valid MASS SBEmails 
        public SendBetterEmailTransmitter getValidMassEmailRequests() {
            LIST<SendBetterEmailRequest> betterEmails = new LIST<SendBetterEmailRequest>();
            LIST<Messaging.MassEmailMessage> massEmails = new LIST<Messaging.MassEmailMessage>();
            for (SendBetterEmailRequest sber : emails) {
                if (sber.isValid && sber.emailMessageType == SendBetterEmailConstant.MASSEMAIL) {
                    Messaging.MassEmailMessage e = sber.toMassEmailMessage();
                    if (e!=null) {
                        massEmails.add(e);
                        betterEmails.add(sber);
                    }
                }
            }
            return new SendBetterEmailTransmitter(betterEmails, massEmails, true);
        }
        
        //Valid SINGLE SBEmails 
        public SendBetterEmailTransmitter getValidSingleEmailRequests() {
            LIST<SendBetterEmailRequest> betterEmails = new LIST<SendBetterEmailRequest>();
            LIST<Messaging.SingleEmailMessage> singleEmails = new LIST<Messaging.SingleEmailMessage>();
            for (SendBetterEmailRequest sber : emails) {
                if (sber.isValid==null && sber?.emailMessageType != SendBetterEmailConstant.MASSEMAIL) {
                    Messaging.SingleEmailMessage singleEmail = sber.toSingleEmailMessage();
                    if (singleEmail!=null) {
                        singleEmails.add(singleEmail);
                        betterEmails.add(sber);
                    }
                }
            }
            return new SendBetterEmailTransmitter(betterEmails, singleEmails, false);
        }

 

    }

    public class SendBetterEmailTransmitter {
        public LIST<SendBetterEmailRequest> betterEmails;
        public boolean isMassEmail;
        public LIST<Messaging.Email> emailMessages;
        public LIST<Messaging.SendEMailResult> sendResults;
        public SendBetterEmailTransmitter(LIST<SendBetterEmailRequest> sbes, LIST<Messaging.Email> emails, boolean isMassEmail) {
            this.betterEmails = sbes;
            this.emailMessages = emails;
            this.isMassEmail = isMassEmail;
        }

        public SendBetterEmailTransmitter send() {
            try {
                if (emailMessages!=null && !emailMessages.IsEmpty()) {
                    this.sendResults = safeSendEmail(emailMessages, false);
                    copySendEmailResultsToSbes(this.sendResults,betterEmails);
                }
            } catch (Exception ex) {
                copySendEmailExceptionToSbes(ex,betterEmails);
            }
            return this;
        }

        private Messaging.SendEmailResult[] safeSendEmail(LIST<Messaging.Email> emails, boolean allOrNothing ) {
            return (SendBetterEmail.haltSendEmail) ? null : Messaging.sendEmail(emails, allOrNothing);
        }
  
        private void copySendEmailResultsToSbes(Messaging.SendEmailResult[] res, SendBetterEmailRequest[] sbes) {
            for (Integer i=0; i<sbes.size(); i++) {
                //res==null - did not actually fire Messaging.sendEmail() as it was intercepted for UT success
                sbes[i].response.isSuccess = (res!=null) ? res[i].isSuccess() : true;
                sbes[i].response.errors = (res!=null) ? SendBetterEmailUtil.getErrorString(res[i].getErrors()) : null; 
                sbes[i].response.templateUsed = sbes[i].EmailTemplate?.Id;
            }       
        }
        private void copySendEmailExceptionToSbes(Exception ex, SendBetterEmailRequest[] sbes) {
            for (Integer i=0; i<sbes.size(); i++) {
                sbes[i].response.isSuccess = false;
                sbes[i].response.errors = ex.getmessage();
            }       
        }  
    }


    public class EmailTemplateSelector {
        MAP<string,EmailTemplate> mapTemplates;
        MAP<string,MAP<string,EmailTemplate>> mapTemplatesbyNameAndLang;
        String orgLocale = SendBetterEmailConstant.getOrganizationLocale(); //local language key for the organization
        //JACK:  ask if needed : private static MAP<string,MAP<string,EmailTemplate>> mapTemplatebyDevNameAndLang;
        public EmailTemplateSelector(LIST<SendBetterEmailRequest> sbes) {
            SET<string> ids = new SET<string>();
            SET<string> names = new SET<string>();
            for(SendBetterEmailRequest sbe : sbes) {
                if (String.isNotBlank(sbe.TemplateId)) ids.add(sbe.TemplateId?.trim());
                if (String.isNotBlank(sbe.TemplateName)) names.add(sbe.TemplateName?.trim());
            }
            mapTemplatesbyNameAndLang = SendBetterEmail.getMapTemplatebyNameAndLang(names);
            mapTemplates = SendBetterEmail.getEmailTemplates(ids);
        }

        public void setTemplate(SendBetterEmailRequest sbe) {
            sbe.EmailTemplate = getTemplate(sbe);
        }

        public EmailTemplate getTemplate(SendBetterEmailRequest sbe) {
            if (sbe.templateID!=null) {
                return getTemplateById(sbe.templateID);
            }
            if (sbe.templateName!=null) {
                return getTemplateByName(sbe.TemplateName,sbe.TemplateLanguage);
            }
            return null;
        }

        private EmailTemplate getTemplateById(string id){
            return mapTemplates.get(id);
        } 
        private EmailTemplate getTemplateByName(string Name, string lang) {
            MAP<string,EmailTemplate> mapLangTemplates = mapTemplatesbyNameAndLang.get(name.toLowercase());
            if (mapLangTemplates!=null) {
                if (mapLangTemplates.size()==1) return mapLangTemplates.values()[0];
                else if (mapLangTemplates.size()>1) {
                    if (lang!=null && mapLangTemplates.containsKey(lang.tolowercase()) ) {
                        return mapLangTemplates.get(lang.tolowercase());
                    }
                    else if ( mapLangTemplates.containskey(orgLocale.tolowercase()) ) {
                    return mapLangTemplates.get(orgLocale.tolowercase());
                    }
                    else {
                        EmailTemplate undef = mapLangTemplates.get('undefined');
                        return (undef!=null) ? undef : mapLangTemplates.values()[0];
                    }
                }
            }
            return null;
        } 
    }


    //JACK: confirm cdl is the only attachment option? and all cdl objects must have a cdl.contentDocumentId (queried) no existing logic for cdl.Id?

    public class AttachmentSelector {
        //MAP<string, ContentVersion> mapCdlIdToContentVersion = new MAP<string, ContentVersion>();
        MAP<string, ContentVersion> mapDocIdToContentVersion = new MAP<string, ContentVersion>();
        public AttachmentSelector(LIST<SendBetterEmailRequest> sbes) {
            SET<Id> docIds = new SET<Id>();
            //SET<ContentDocumentLink> cdlIds;
            SET<string> names;
            for(SendBetterEmailRequest sbe : sbes) {
                if (sbe.contentDocumentAttachments!=null) {
                    for (ContentDocumentLink cdl : sbe.contentDocumentAttachments){
                        if (cdl.ContentDocumentId!=null) {
                            docIds.add(cdl.ContentDocumentId);
                        }
                    }
                    for (ContentVersion cv : [ SELECT Id, PathOnClient, Title, VersionData, VersionNumber, FileType, ContentDocumentId, FileExtension
                                                FROM ContentVersion
                                                WHERE ContentDocumentId IN :docIds ]) {
                        mapDocIdToContentVersion.put(cv.ContentDocumentId, cv);
                    }
                }
            }
        }

        public void setAttachments(SendBetterEmailRequest sbe) {
            sbe.ContentVersions = getAttachments(sbe);
        }
        
        public SET<ContentVersion> getAttachments(SendBetterEmailRequest sbe) {
            if (sbe.contentDocumentAttachments!=null) {
                return getSetofContentVersionsByCdlsWithDocId(sbe.contentDocumentAttachments);
            }
            return null;
        }


        // todays use-case using mail.setEntityAttachments(with ContentVersion) - Array of IDs of Document, ContentVersion, or Attachment items to attach to the email.
        // JACK:  this maybe simplified if we can just base on ContentDocument (I assume it sends latest version DO YOU WANT to support previous versions?)
        //        add to errors if missing document(s)?
        public SET<ContentVersion> getSetofContentVersionsByCdlsWithDocId(LIST<ContentDocumentLink> cdls) {
            SET<ContentVersion> rtn = new SET<ContentVersion>();
            for (ContentDocumentLink cdl : cdls) {
                if (mapDocIdToContentVersion.containsKey(cdl.ContentDocumentId)) {
                    rtn.add(mapDocIdToContentVersion.get(cdl.ContentDocumentId));
                }
            }
            return rtn;
        }
    }


    public static void normalizeSbe(SendBetterEmailRequest sbe) {
        sbe.setSaveAsTask = sbe.saveAsTask;
        sbe.setSaveAsActivity = sbe.saveAsActivity;
        sbe.emailMessageType = sbe.emailMessageType == null ? 'singleEmail' : sbe.emailMessageType;
        //if saveAsTask is null, it will default to whatever saveAsActivity is, but if recordId is null, will set it to false
        sbe.setSaveAsTask = sbe.setSaveAsTask != null ? sbe.setSaveAsTask : 
            (sbe.recordId == null ? false : (sbe.setSaveAsActivity == null ? false : sbe.setSaveAsActivity));
        sbe.setSaveAsActivity = sbe.setSaveAsActivity == null ? false : sbe.setSaveAsActivity;
        sbe.subject = (String.IsEmpty(sbe.subject?.trim())) ? null : sbe.subject;
        sbe.setTreatTargetObjectAsRecipient = sbe.setTreatTargetObjectAsRecipient==null ? SendBetterEmailConstant.DEFAULT_TREAT_TARGET_OBJECT_AS_RECIPIENT : sbe.setTreatTargetObjectAsRecipient;
        sbe.UseSalesforceSignature = sbe.UseSalesforceSignature==null ? false : sbe.UseSalesforceSignature;
        sbe.bcc = sbe.bcc==null ? false : sbe.bcc;

    }

    
    @invocableMethod(
        label='Send Better Email'
        configurationEditor='c:sendBetterEmailCPE'
        category='Email'
    )
    public static List<SendBetterEmailResponse> SendEmail( List<SendBetterEmailRequest> requests ) {
       


        SendBetterEmailDispatcher dispatcher = new SendBetterEmailDispatcher(requests);
        dispatcher.validate();
        dispatcher.dispatch();
        

        //TODO:  move to send()
        /*
        //JACK add these checks?
        reserveMassEmailCapacity(amountReserved)
        Reserves email capacity to send mass email to the specified number of email addresses, after the current transaction commits.
        reserveSingleEmailCapacity(amountReserved)
        Reserves email capacity to send single email to the specified number of email addresses, after the current transaction commits.

        respecting - Email Opt Out ?  do you have a settings/CMDT?
        */
      
           
        
/*

       /*
 
   
        List<SendBetterEmailAddTasksToEmail.TaskWrapper> lstTaskWrapper = new List<SendBetterEmailAddTasksToEmail.TaskWrapper>();
        

        response.isSuccess = true;
        if (request.setSaveAsTask == true) {
            if (request.whatIds != null && request.whatIds.size() > 0) {
                lstTaskWrapper.addAll(SendBetterEmailAddTasksToEmail.addTasks(request,null,mapIdByEmailTemplate,mapRecordIdByName));
            } else {
                response.taskIds = new List<String>{
                    'Error:  Mass Email requires whatIds if saveAsTask'
                };
            }
        }
  
      
            for (integer i = 0; i < singleSendEmailResults.size(); i++) {
                SendBetterEmailRequest request = singleEmailRequestToSend[i];
                SendBetterEmailResponse response = responseList[request.index];
                Messaging.SendEmailResult emailResult = singleSendEmailResults[i];

                JACK: Dont understand the purpose of this logic
                //Handle differently,  dont assume error due to saveAstask w/ User
                if (
                    emailResult.isSuccess() != true &&
                    !(test.isRunningTest() &&
                    request.setSaveAsTask &&
                    ((Id) request.recordId).getSObjectType() ==
                    Schema.User.sObjectType)
                ) {
                    response.isSuccess = false;
                    response.errors = sendBetterEmailUtil.getErrorString(
                        emailResult.getErrors()
                    );
                } else {
                    response.isSuccess = true;
                    if (request.setSaveAsTask == true) {
                        if (request.recordId != null && request.recordId.length()> 0) {
                            lstTaskWrapper.addAll(SendBetterEmailAddTasksToEmail.addTasks(request,mapRecordIdByName));
                        }
                    }
                }
            }
        }

        //Insert Tasks /  save results to response

        for (SendBetterEmailAddTasksToEmail.TaskWrapper taskWrap : lstTaskWrapper) {
            lstTaskToInsert.add(taskWrap.taskRec);
        }
        List<Database.SaveResult> taskInsertResults = Database.insert(lstTaskToInsert,false);

        for (integer i = 0; i < taskInsertResults.size(); i++) {
            Database.SaveResult taskResult = taskInsertResults[i];
            SendBetterEmailAddTasksToEmail.TaskWrapper taskWrapper = lstTaskWrapper[i];
            SendBetterEmailResponse reponse = responseList[taskWrapper.requestIndex];
            String taskId = taskResult.getId();
            Task taskRecord = lstTaskToInsert[i];
            if (taskResult.isSuccess()) {
                reponse.taskIds.add(taskId);
            } else {
                string msg = 'Task Insert failed for RecordId ' + taskRecord.whatId + ' with error ' + sendBetterEmailUtil.getDatabaseErrorString(taskResult.getErrors())
                reponse.taskErrors.add(msg);
            }
        }

*/
        //report back the results
        LIST<SendBetterEmailResponse> responses = new LIST<SendBetterEmailResponse>();
        boolean atLeastOneSent = false;
        for (SendBetterEmailRequest sbe : requests) {
            responses.add(sbe.response);
            if (sbe.Response?.isSuccess==true) {
                atLeastOneSent = true;
            }
        }
        if (!atLeastOneSent) {
            throw new InvocableActionException(
                'No Messages were sent.  First Error: ' + responses[0].errors
            );
        }
        
        return responses;
    }

    public class InvocableActionException extends Exception {}


    //system.debug(SendBetterEmail.getLanguageFromTemplateDescription('Test Email Template - Language Specified '));

	public static string getLanguageFromTemplateDescription(string descr) {
        string lang = descr?.substringAfter(SendBetterEmailConstant.LANGUAGE_EQUAL).substringBefore(SendBetterEmailConstant.DOUBLE_QUOTE);
        return String.isBlank(lang) ? 'undefined' : lang;
	}

    /*  FUTURE MAYBE
    // MAP<templateName,<templateLang,EmailTemplate>
    public static MAP<string,MAP<string,EmailTemplate>> getMapTemplatebyDevNameAndLang(SET<strings> templateNames) {
        MAP<string,MAP<string,EmailTemplate>> rtn = new MAP<string,MAP<string,EmailTemplate>>();
        for (EmailTemplate et : [   SELECT Id, Description, Name 
                                    FROM EmailTemplate
                                    WHERE Name IN :templateNames AND isActive = TRUE]) {
            if (!rtn.contains(et.Name)) {
                rtn.put(et.Name, new MAP<string,EmailTemplate>());
            }
            string lang = getLanguageFromTemplateDescription(et.Description);
            if (lang==null) lang='NONE';
            rtn.get(Name).put(lang,et);
        }
        return rtn;
    }
    */

    /**
	* @description: wrapper for handling Messaging.sendEmail() in Unit Tests with emailDeliverablity disabled
	* @author Tom Snyder <tom@3ddd.com> | 2021-10-02 
	* @param sbers SingleEmailMessage[] or MassEmailMessage[]
	* @param allOrNothing - The optional opt_allOrNone parameter specifies whether sendEmail prevents delivery of all other messages when any of the messages fail due to an error (true), 
				or whether it allows delivery of the messages that don't have errors (false). The default is true.
	* @return emailSendEmailResult[] -  if SendBetterEmail.haltSendEmail == false else NULL
	**/


    //map keyset is lowercase
    public static MAP<string,MAP<string,EmailTemplate>> getMapTemplatebyNameAndLang(SET<string> templateNames) {
        MAP<string,MAP<string,EmailTemplate>> rtn = new MAP<string,MAP<string,EmailTemplate>>();
        if (templateNames!=null && !templateNames.isEmpty()) {
            for (EmailTemplate et : [   SELECT Id, Description, Name, RelatedEntityType, TemplateType
                                        FROM EmailTemplate
                                        WHERE Name IN :templateNames AND isActive = TRUE]) {
                if (!rtn.containsKey(et.Name.toLowerCase())) {
                    rtn.put(et.Name.toLowerCase(), new MAP<string,EmailTemplate>());
                }
                string lang = getLanguageFromTemplateDescription(et.Description);
                rtn.get(et.Name.toLowerCase()).put(lang.toLowerCase(),et);
            }
        }
        return rtn;
    }

    public static MAP<string,EmailTemplate> getEmailTemplates(SET<string> ids) {
        return new MAP<string,EmailTemplate>(   [SELECT Id, Description, Name, Subject, RelatedEntityType, TemplateType
                                                FROM EmailTemplate
                                                WHERE Id IN :ids AND isActive = TRUE]   );
    }


    public static boolean validateSbe(SendBetterEmailRequest sbe) {

        //Validate
 
        if (String.isNotBlank(sbe.templateName) && String.isNotBlank(sbe.templateID)) {
            sbe.response.errors = 'You\'re trying to pass in both the name of the template and a template ID. Gotta pick one or the other. Use templateName to select the first matching template qualified with \'Language="xxx_YY"\' in the Description.  The templateID represents a specific Salesforce Email Template (either Classic or Lightning).';
            return false;
        }
        if ( sbe.EmailTemplate==null && (String.isNotBlank(sbe.templateName) || String.isNotBlank(sbe.templateID)) ) {
            if (String.isNotBlank(sbe.templateName)) {
                sbe.response.errors =  'Could not find email template named "' +sbe.templateName +'".  Please have your administrator check the name and/or accessibility of this template';
            }
            else {
                sbe.response.errors =  'Could not find email template ID "' +sbe.templateID +'".  Please have your administrator check the id and/or accessibility of this template';
            }
            return false;
        }

        if ( (String.isNotBlank(sbe.templateName) || String.isNotBlank(sbe.templateID)) && ((sbe.HTMLbody != null) || (sbe.plainTextBody != null)) ) {
            sbe.response.errors = 'You\'re trying to pass in both a plaintext/html body and a template ID. Gotta pick one or the other. Make sure you\'re not confusing the Text Template resources in Flow, (which you can pass into either the HTMLBody or the plainTextBody) with the templateID, which represents a Salesforce Email Template (either Classic or Lightning).';
            return false;
        }

        if (sbe.EmailTemplate==null && sbe.HTMLbody == null && sbe.plainTextBody == null) {
            sbe.response.errors = 'Body text must be provided to Send Better Email Action, either via HTMLbody, plainTextBody, or a templateID';
            return false;
        }

        if ( sbe.emailMessageType == SendBetterEmailConstant.MASSEMAIL) {
            if (String.isBlank(sbe.description)) {
                sbe.response.errors  = 'You must specify a description for mass email message collections.';
                return false;
            }
            if (sbe.targetObjectIds==null || sbe.targetObjectIds.IsEmpty()) {
                sbe.response.errors = 'You must specify a collection of targetObjectIds - required parameter for mass emails.';
                return false;
            }
            if ( sbe.EmailTemplate?.TemplateType?.tolowercase()=='visualforce') {
                sbe.response.errors ='Visualforce email templates cannot be used for mass email.';
                return false;
            }
            //JACK:  I dont think this is entirly correct base on sf docs  (MASS-EMAIL)
            if ( (sbe.whatIds!=null && sbe.targetObjectIds!=null) && sbe.whatIds?.size() != sbe.targetObjectIds?.size() ) { 
                sbe.response.errors = 'You must match targetObjectIds one-for-one with whatIds.';
                return false;
            }
            /* - this still sends email and stuffs error in TaskId response
            if ( sbe.setSaveAsTask == true && sbe.whatIds==null) {
                sbe.response.errors ='Error:  Mass Email requires whatIds if saveAsTask'
            };
            */
        }

        
        /*  JACK:  looks like there may have been some code to do this manually  allow?
        if ( sbe.setSaveAsTask == true && sbe.recordId == null ) {
            sbe.response.errors = 'In order to log this email send as a task, you need to pass in a recordId';
            return false;
        }
        */

        if ( sbe.recordId?.startsWith('005')==true && sbe.templateTargetObjectId?.startsWith('005')==true ) {
            sbe.response.errors = 'WhatId is not available for sending emails to Users when User is also the template targetObject';
            return false;
        }




        return true;
    }



}