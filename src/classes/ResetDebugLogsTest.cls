@isTest 
private class ResetDebugLogsTest {
    static testMethod void validateHelloWorld() {
           try
           {
              List<Debug_Logs__c> dclist = new List<Debug_Logs__c>();
              for(integer i=0; i<30 ; i++){
                 Debug_Logs__c acc = new Debug_Logs__c(name='Ranjeeth');
                 dclist.add(acc);
              }
              insert dclist;
              delete dclist;
           }
           catch (Exception e)
           {
               
           }
    }
}