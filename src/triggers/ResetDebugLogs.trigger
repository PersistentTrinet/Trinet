trigger ResetDebugLogs on Debug_Logs__c (before insert)
 {
   if(trigger.isInsert){
       List<Debug_Logs__c> debugList = [select id,name from Debug_Logs__c];
         if(debugList.size() >= 20){
              delete debugList; 
          }
       List<Debug_Logs__c> insertList = trigger.new;
       
       if(insertList.size() > 20){
            for(Debug_Logs__c debug : trigger.new){
                 debug.addError('Debug Log Object Not support inserting more than 20 records at a time');
            }       
       }   
    } 
 }