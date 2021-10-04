/**
 * @description       : Constants for SendBetterEmail
 * @author            : Mohith
 * @group             : 
 * @last modified on  : 2021-10-01
 * @last modified by  : Tom Snyder <tom@3ddd.com>
 * Modifications Log 
 * Ver   Date         Author         Modification
 * 1.0   02-06-2021   Jack D. Pond   Added DEFAULT_TREAT_TARGET_OBJECT_AS_RECIPIENT
**/
public inherited sharing class SendBetterEmailConstant {
    public static String getOrganizationLocale() {
        return [SELECT LanguageLocaleKey FROM Organization LIMIT 1]
        .LanguageLocaleKey;
    }

    public static final String MASSEMAIL = 'massEmail';

    public static final String LANGUAGE_EQUAL = 'Language="';

    public static final String DOUBLE_QUOTE = '"';

    public static final Boolean DEFAULT_TREAT_TARGET_OBJECT_AS_RECIPIENT = true;

    public static boolean EMAIL_DELIVERY_ENABLED {
        get {
            try {
                Messaging.reserveSingleEmailCapacity(1);
                Messaging.reserveMassEmailCapacity(1);
                return true;
            } catch (System.NoAccessException e) {
                return false;
            }
        }
    }

    
}