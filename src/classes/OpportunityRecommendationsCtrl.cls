/**
Author          :   Sriteja Prabhala
Created On      :   5th May, 2015
Last Modified   :   25th May, 2015
Purpose         :   Extension Controller for OpportunityRecommendations page. Used to make callouts to perform search.
*/
global with sharing class OpportunityRecommendationsCtrl {
    /* Opportunity Variables Creation - Start */
    private Opportunity curOpp;
    private list<OpportunityCompetitor> oppComps;
    private list<String> oppProds;
    private final ApexPages.StandardController controller;
    /* Opportunity Variables Creation - End */
    
    /* Config Variables Creation - Start */
    private String clientId;
    private String clientSecret;
    public  String tenantURL            {get;private set;}
    /* Config Variables Creation - End */
    
    /* Search Response Variables Creation - Start */
    public SearchResponse searchResp;
    public list<Searches> allsearches   {get;set;}
    /* Search Response Variables Creation - End */
    
    /* Sharing Related Variables Creation - Start */
    public String userOrGrpId           {get;set;}
    public String userName              {get;set;}
    public String userType              {get;set;}
    public String userComment           {get;set;}
    /* Sharing Related Variables Creation - End */
    
    /* Common Variables Creation - Start */
    global String nameSpace             {get;set;}
    public Boolean hasAccess            {get;set;} //Used to check if he has Access
    public Boolean isSuccess            {get;set;} //Used to set the status of response
    public Boolean isFavorite           {get;set;} //Used for Favorites, specifically
    public String courseId              {get;set;} //Used to pass on the current CourseID
    private User curUser;
    public Integer maxPageNum           {get;set;}
    public Integer pageNum              {get;set;}
    public String access_token          {get;set;}
    Public static Boolean isErrorOccured{get;set;}
    Public string currentUser           {get;set;}  // Used to store in the debug logs
    public static string typeOfException{get;set;} // Used to store in the debug logs
    public string searchResults         {get;set;} 
    public static string responseMessage {get;set;} // used to store the response in the debug logs 
    public Profile profileName           {get;set;}
    // Used to store in the debug logs
    /* Common Variables Creation - End */
        
    global OpportunityRecommendationsCtrl(ApexPages.StandardController controller){
        /* Initializing Record - Start */
        this.controller = controller;
        isErrorOccured = false;
        isFavorite = false;
        isSuccess = false;
        
        currentUser = UserInfo.getName();
        ApexClass acNameSpaceList = [SELECT NameSpacePrefix FROM ApexClass WHERE Name = 'OpportunityRecommendationsCtrl'];
        nameSpace = acNameSpaceList.NameSpacePrefix;
        
        if(!Test.isRunningTest()){
            this.controller.addFields(new list<String>{'Name','StageName','Amount','ExpectedRevenue','Probability','LastModifiedBy.Email'});
        }
        curOpp = (Opportunity) controller.getRecord();
        oppProds = new list<String>();
        for(Opportunity opp : [Select Id, (Select Id, CompetitorName from OpportunityCompetitors), (Select Id, PricebookEntry.Product2.Name From OpportunityLineItems) from Opportunity where Id = :curOpp.id]){
            oppComps = opp.OpportunityCompetitors;
            for(OpportunityLineItem oppLItem : opp.OpportunityLineItems){
                oppProds.add(oppLItem.PricebookEntry.Product2.Name);
            }
        }
        //oppComps = [Select Id, CompetitorName from OpportunityCompetitor where OpportunityId = :curOpp.id];
        system.debug('curOpp---'+curOpp);
        
        curUser = [Select Id,Name,Email from User where Id = :Userinfo.getUserId()];
        list<PermissionSetAssignment> permAssignLst = [Select Id, AssigneeID from PermissionSetAssignment where PermissionSet.Name = 'Kaybus_Permission_Set' And AssigneeID = :curUser.Id];
        if(permAssignLst != null && permAssignLst.size() > 0){
            hasAccess = true;
        }else{
            hasAccess = false;
        }
        
        /* Initializing Record - End */
        
        /* Initializing Variables - Start */
        //clientId = KaybusConfig__c.getAll().containsKey('ClientId') ? KaybusConfig__c.getAll().get('ClientId').Value__c : ''; //Consumer Key
        clientId = '1';
        //clientSecret = KaybusConfig__c.getAll().containsKey('ClientSecret') ? KaybusConfig__c.getAll().get('ClientSecret').Value__c : '';
        clientSecret = 'secret';
        tenantURL = KaybusConfig__c.getAll().containsKey('Tenant') ? KaybusConfig__c.getAll().get('Tenant').Value__c : '';
        
        system.debug('--clientId--'+clientId);
        system.debug('--clientSecret--'+clientSecret);
        system.debug('--tenantURL--'+tenantURL);
        
        maxPageNum = 0;
        pageNum = 1;
        
        
        /* to know the user is System administrator */
        
        profileName = [Select Name from Profile where Id =: userinfo.getProfileid()];
        system.debug('--profileName--'+profileName.Name);
        
        /* Initializing Variables - End */
        performSearch(); // Performing Search Logic
    }
    
    public void performSearch(){
        try{
            allsearches = new list<Searches>();
            system.debug('---pageNum---'+pageNum);
            if(clientId != '' && clientSecret != '' && tenantURL != ''){
                // Request 1 : To obtain Access Token
                AuthResponse authRep = new AuthResponse();
                authRep = obtainAccessToken(curUser.Email, clientId, clientSecret, tenantURL);
                if(authRep.access_token == null){
                    isErrorOccured = true;
                }
                if(authRep != null && authRep.access_token != null){ // Only entering if access_token is obtained
                    access_token = authRep.access_token;    
                    system.debug('----access_token---'+access_token);
                    // Request 2 : To obtain Search Results
                    searchResp = obtainSearchResponse(curOpp, oppComps, oppProds, pageNum, access_token, tenantURL);
                    
                    system.debug('--searchResp'+searchResp.meta);
                    system.debug('--searchResp'+searchResp.searches+(searchResp.searches == null));
                    if(searchResp.meta == null){
                        isErrorOccured = true;
                    }
                    
                    if(maxPageNum == 0){
                        //maxPageNum = searchResp.meta != null ? searchResp.meta.pagination.total/4 : 1;
                        //maxPageNum = Math.mod(searchResp.meta != null ? searchResp.meta.pagination.total : 0 ,4) > 0 ? maxPageNum + 1 : maxPageNum;
                        maxPageNum = searchResp.meta != null ? searchResp.meta.pagination.total_pages : 1;
                        system.debug('----maxPageNum----'+maxPageNum);
                    }
                    // Request 3 : To obtain Named Lists - Favorites 
                    NamedListResponse nameResponse = new NamedListResponse();
                    nameResponse = obtainFavorites(access_token, tenantURL);
                    system.debug('---NamedLists----'+nameResponse.named_lists);
                    
                    /* Preparing List with Favorites - Start */
                    for(Searches src : searchResp.searches){
                        if(nameResponse.named_lists != null && nameResponse.named_lists.size() > 0){
                            src.isFavorited = isCourseFavorited(src.id ,nameResponse.named_lists[0].named_list_items);
                        }else{
                            src.isFavorited = false;
                        }
                        allsearches.add(src);
                    }
                    /* Preparing List with Favorites - End */
                    system.debug('----allsearches----'+allsearches);
                    responseMessage = String.valueOf(allsearches);
                }
            }
        }catch(Exception e){
            isErrorOccured = true;
            typeOfException = string.valueOf( e.getStackTraceString()) + ' getCause '+ string.valueOf( e.getCause())+' getLineNumber '+
                              string.valueOf( e.getLineNumber()) + ' getMessage '+ string.valueOf( e.getMessage())+' getTypeName '+ 
                              string.valueOf( e.getTypeName());
            system.debug('----isErrorOccured----'+isErrorOccured);
            system.debug('----exception----'+e);
            typeOfException = typeOfException.replaceAll('\'', '');  
        }
    }
    
    public void favouriteItem(){
        try{
            isSuccess = false;
            system.debug('courseId----'+courseId);
            if(clientId != '' && clientSecret != '' && tenantURL != ''){
                // Request 1 : To obtain Access Token
                AuthResponse authRep = new AuthResponse();
                authRep = obtainAccessToken(curUser.Email, clientId, clientSecret, tenantURL);
                            
                if(authRep != null && authRep.access_token != null){ // Only entering if access_token is obtained
                    system.debug('----access_token---'+authRep.access_token);
                    access_token = authRep.access_token;
                    // Request 2 : To obtain Named Lists - Favorites 
                    NamedListResponse nameResponse = new NamedListResponse();
                    nameResponse = obtainFavorites(access_token, tenantURL);
                    system.debug('---NamedLists----'+nameResponse.named_lists);
                    
                    String favoriteNamedListId = '';
                    if(nameResponse.named_lists != null && nameResponse.named_lists.size() > 0){
                        favoriteNamedListId = nameResponse.named_lists[0].id;
                    }else{
                        // Request 2.1 : To Create Named Lists - Favorites 
                        NameListCreationResponse nameListResponse = new NameListCreationResponse();
                        nameListResponse = createFavoriteList(access_token, tenantURL);
                        favoriteNamedListId = nameListResponse.named_list.id;
                    }
                    system.debug('----favoriteNamedListId---'+favoriteNamedListId);
                    if(!isFavorite){
                        // Request 3 : To Set as Favorite 
                        isSuccess = setFavorite(favoriteNamedListId, courseId, access_token, tenantURL);
                        for(Searches srch : allsearches){
                            if(srch.id.equals(courseId)){
                                system.debug('----Found----'+srch);
                                srch.isFavorited = true;
                            }
                        }
                    }else{
                        String tobeDeletedId = '';
                        for(Named_list_items nameLstItem : nameResponse.named_lists[0].named_list_items){
                            if(nameLstItem.listable_id.equals(courseId)){
                                tobeDeletedId = nameLstItem.id;
                            }
                        }
                        // Request 3 : To Delete Favorite
                        isSuccess = deleteFavorite(tobeDeletedId, access_token, tenantURL);
                        for(Searches srch : allsearches){
                            if(srch.id.equals(courseId)){
                                system.debug('----Found----'+srch);
                                srch.isFavorited = false;
                            }
                        }
                    }
                    
                }
            }
            system.debug('---allsearches--'+allsearches);
             responseMessage = String.valueOf(allsearches);
        }catch(Exception e){
            isErrorOccured = true;
            typeOfException = string.valueOf( e.getStackTraceString()) + ' getCause '+ string.valueOf( e.getCause())+' getLineNumber '+
                              string.valueOf( e.getLineNumber()) + ' getMessage '+ string.valueOf( e.getMessage())+' getTypeName '+ 
                              string.valueOf( e.getTypeName());
            system.debug('----exception----'+e);
            
        }
    }
    public Boolean isCourseFavorited(String courseId, List<Named_list_items> named_list_items){
        for(Named_list_items lstItem : named_list_items){
            if(courseId.equalsIgnoreCase(lstItem.listable_id)){
                return true;
            }
        }
        return false;
    }
    @RemoteAction
    global static list<UserOrGroupDetail> queryUsers(String queryTerm){     
       queryTerm = queryTerm.replaceAll(' ','+');
       //String clientId = KaybusConfig__c.getAll().containsKey('ClientId') ? KaybusConfig__c.getAll().get('ClientId').Value__c : ''; 
       String clientId = '1';
       //String clientSecret = KaybusConfig__c.getAll().containsKey('ClientSecret') ? KaybusConfig__c.getAll().get('ClientSecret').Value__c : '';
       String clientSecret = 'secret'; 
       String tenantURL = KaybusConfig__c.getAll().containsKey('Tenant') ? KaybusConfig__c.getAll().get('Tenant').Value__c : '';  
       
       String access_token = '';
       
       User curUser = [Select Id,Name,Email from User where Id = :Userinfo.getUserId()];
       list<UserOrGroupDetail> options = new list<UserOrGroupDetail>();
       
       if(clientId != '' && clientSecret != '' && tenantURL != ''){
            // Request 1 : To obtain Access Token
            AuthResponse authRep = new AuthResponse();
            authRep = obtainAccessToken(curUser.Email, clientId, clientSecret, tenantURL);
                        
            if(authRep != null && authRep.access_token != null){ // Only entering if access_token is obtained
                system.debug('----access_token---'+authRep.access_token);
                access_token = authRep.access_token;
                // Request 2 : To obtain Search Results
                UserOrGroups allUsersOrGrps = new UserOrGroups();
                allUsersOrGrps = getUsersAndGroups(queryTerm, access_token, tenantURL);
                
                /* Preparing List with Users and Groups - Start */
                for(Users usr: allUsersOrGrps.users){
                    UserOrGroupDetail ugOpt = new UserOrGroupDetail();
                    ugOpt.id = usr.id;
                    ugOpt.name = usr.last_name +', '+ usr.first_name + ' - ' + usr.email;
                    ugOpt.type = 'User';
                    options.add(ugOpt);
                }
                for(Groups usr: allUsersOrGrps.groups){
                    UserOrGroupDetail ugOpt = new UserOrGroupDetail();
                    ugOpt.id = usr.id;
                    ugOpt.name = usr.name;
                    ugOpt.type = 'Group';
                    options.add(ugOpt);
                }
                /* Preparing List with Users and Groups - End */
                system.debug('----options----'+options);
            }
        }
        return options;
    }
    
    public void shareContent(){
        system.debug('-------courseId----'+courseId);
        system.debug('-------userOrGrpId----'+userOrGrpId);
        system.debug('-------userName----'+userName);
        system.debug('-------userType----'+userType);
        system.debug('-------userComment----'+userComment);
        isSuccess = false;
        try{
            if(clientId != '' && clientSecret != '' && tenantURL != ''){
                // Request 1 : To obtain Access Token 
                AuthResponse authRep = new AuthResponse();
                authRep = obtainAccessToken(curUser.Email, clientId, clientSecret, tenantURL);
                            
                if(authRep != null && authRep.access_token != null){ // Only entering if access_token is obtained
                    system.debug('----access_token---'+authRep.access_token);
                    access_token = authRep.access_token;
                    // Request 2 : To Post a Share
                    isSuccess = shareToUser(userOrGrpId, userName, userType, userComment, courseId, access_token, tenantURL);
                }
            }
            system.debug('---allsearches--'+allsearches);
             responseMessage = String.valueOf(allsearches);
        }catch(Exception e){
            isErrorOccured = true;
            typeOfException = string.valueOf( e.getStackTraceString()) + ' getCause '+ string.valueOf( e.getCause())+' getLineNumber '+
                              string.valueOf( e.getLineNumber()) + ' getMessage '+ string.valueOf( e.getMessage())+' getTypeName '+ 
                              string.valueOf( e.getTypeName());
           typeOfException = typeOfException.replaceAll('\'', ''); 
            system.debug('----exception----'+e);
        }
    }
    /*  Request  To obtain Access Token  */
    public static AuthResponse obtainAccessToken(String userEmail, String clientId, String clientSecret, String tenantURL){
        try{
            Blob authBlob = Blob.valueOf(clientId+':'+clientSecret); //Preparing Base64Blob to Encode later
            String authHeader = 'Basic ' + EncodingUtil.base64Encode(authBlob); //Encoding ClientID& Secret as String
            
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint(tenantURL+'/policy/oauth/access_token');
            req.setMethod('POST');
            req.setHeader('Authorization',authHeader);
            req.setBody('grant_type='+EncodingUtil.urlEncode('guest_extension', 'UTF-8')+'&username='+EncodingUtil.urlEncode(userEmail, 'UTF-8'));
            HttpResponse res = http.send(req);
            system.debug('----AuthResponse----'+res.getBody());
             responseMessage = String.valueOf(res.getBody());
            return (AuthResponse) System.JSON.deserialize(res.getBody(), AuthResponse.class);
        }catch(Exception e){
            isErrorOccured = true;
            typeOfException = string.valueOf( e.getStackTraceString()) + ' getCause '+ string.valueOf( e.getCause())+' getLineNumber '+
                              string.valueOf( e.getLineNumber()) + ' getMessage '+ string.valueOf( e.getMessage())+' getTypeName '+ 
                              string.valueOf( e.getTypeName());
            system.debug('----exception----'+e);
            typeOfException = typeOfException.replaceAll('\'', ''); 
            return new AuthResponse();
        }
    }
    /*  Request  To obtain Search Response  */
    public static SearchResponse obtainSearchResponse(Opportunity curOpp, list<OpportunityCompetitor> oppComps, list<String> oppProds, Integer pageNum, String access_token, String tenantURL){
        try{
            
            Map<string, String> map1 = new Map<string, String>();
            id OppId = curOpp.id;
            user userEmail;
            ApexClass acNameSpaceList = [SELECT NameSpacePrefix FROM ApexClass WHERE Name = 'OpportunityRecommendationsCtrl'];
            string fieldSetName = 'Recommendation_Attributes';
            string nameSpace = acNameSpaceList.NameSpacePrefix+'__';
            string fieldsetNameSpace = nameSpace+fieldSetName;
            string query = 'select';
            for(Schema.FieldSetMember s:Schema.SObjectType.Opportunity.fieldSets.getMap().get(fieldsetNameSpace).getFields()){
                   system.debug(s.getFieldPath());
                   query += ' ' + s.getFieldPath() + ','; 
                   string fieldPath = s.getFieldPath();
                   system.debug(nameSpace);
                    
                    // Replace KaybusApi__ string becuase Schema not returning the api field lables
                      if(fieldPath.contains(nameSpace)){
                      fieldpath = fieldPath.replaceAll(nameSpace,'');
                    } 
                    
                   map1.put(fieldpath, fieldpath);
              }
            query = query.endsWith(',') ? query.substring(0, query.length() - 1) : query;
            query += ' FROM ' + 'opportunity'+' WHERE id =: OppId'; 
            system.debug(query);
            opportunity opportunitys = database.query(query);
            
            String reqEndPoint = tenantURL+'/api/searches?search_type=recommendations&context=salesforce&activity=opportunities&page='+ pageNum +'&per_page=4'+ '&thumbnails=grid%2Furl&max_results=20&hl=true';
            
            string TypeObject = 'Opportunity';
            Map<String, Schema.SObjectField> M = Schema.SObjectType.opportunity.fields.getMap();
            
    
            if(map1.containsKey('LastModifiedBy.Email')){
                 userEmail = [select id,name,email from user where id =: opportunitys.LastModifiedById];
                 reqEndPoint = reqEndPoint+'&LastModifiedBy='+userEmail.email;
            }
            
            
            for(string objectFieldValue :map1.keySet()){
                   String fieldpath  =objectFieldValue;
                   if(! fieldpath.contains('.') && map1.containsKey(fieldpath)){
                       string fieldValue =string.valueof(opportunitys.get(fieldpath));
                       Schema.SObjectField field = M.get(fieldpath);
                       Schema.DisplayType FldType = field.getDescribe().getType();
                       string fieldType = string.valueOf( field.getDescribe().getType());
                       system.debug(field+'******'+FldType);
                       if(fieldValue ==  null && (fieldType == 'CURRENCY' || fieldType == 'PERCENT' || fieldType == 'Number' || fieldType=='PHONE')){
                           reqEndPoint = reqEndPoint+'&'+fieldpath+'='+'0.0';
                       }
                       else {
                             if(fieldType == 'STRING' && fieldValue ==  null){
                               reqEndPoint = reqEndPoint+'&'+fieldpath+'='+'';
                             }
                             else {
                                   if((fieldType == 'STRING' || fieldType == 'PICKLIST') && fieldValue !=  null){
                                       string replaceSpaces = fieldValue.replaceAll(' ','+');
                                       reqEndPoint = reqEndPoint+'&'+fieldpath+'='+replaceSpaces;
                                   }
                                 else{                                      
                                          reqEndPoint = reqEndPoint+'&'+fieldpath+'='+fieldValue;
                                 }
                             }
                       } 
                }
            } 
            
            
                
            system.debug(reqEndPoint);
            
            /*  Http http = new Http();
            HttpRequest req = new HttpRequest();
            
            if(oppComps != null && !oppComps.isEmpty()){    
                reqEndPoint +='&Competitors=';
                for(OpportunityCompetitor oc : oppComps){
                    reqEndPoint += oc.CompetitorName.replaceAll(' ','+') + ',';
                }     
                reqEndPoint = reqEndPoint.endsWith(',') ? reqEndPoint.substring(0, reqEndPoint.length() - 1) : reqEndPoint;
            }  
            if(oppProds != null && !oppProds.isEmpty()){
                reqEndPoint+='&Products=';
                for(String prodName : oppProds){
                    reqEndPoint += prodName.replaceAll(' ','+') + ',';
                }
                reqEndPoint = reqEndPoint.endsWith(',') ? reqEndPoint.substring(0, reqEndPoint.length() - 1) : reqEndPoint;
            } */
            
            // Used to make the child object records Dynamic -- AE-1039
            
            String objectName = 'OpportunityLineItem';
            
            List<Schema.DescribeSObjectResult> describeSobjectsResult = Schema.describeSObjects(new List<String>{objectName}); // this can accept list of strings, we describe only one object here
            String objectLabel = describeSobjectsResult[0].getLabel();
            Map<String, Schema.SObjectField> allFields = describeSobjectsResult[0].fields.getMap();
            
            MAP<string, string > custommap = new map<string, string>();
            MAP<string, string > productsmap = new map<string, string>();
            string Oppidsearch = string.valueof(curOpp.id);
            set<string> objectset = new set<string>();
            string s = 'select id,name,';
                 boolean b1 = false;
            Map<string, set<string>> nameAndFields = new Map<string, set<string>>();
            string productname ;
            string productobject ;    
            for (KaybusConfig__c item : KaybusConfig__c.getAll().values()) {
                      if(item.Field_Name__c != null && item.RelationshipName__c != null ){
                        if(item.Field_Name__c.contains('Product2') && item.RelationshipName__c.contains('OpportunityLineItem')){
                             b1 = true;
                            productname = item.RelationshipName__c;
                            productobject  = item.Field_Name__c;
                        }
                        else {
                             s = s + '(select id,';  
                             //system.debug(item.kaybustestapi__Fields__c);
                             s = s + item.Field_Name__c +' from '+ item.RelationshipName__c+')'+',';
                             objectset.add(item.RelationshipName__c);
                             custommap.put(item.RelationshipName__c, item.Field_Name__c);
                        }
                    }
            }
                 s = s.endsWith(',') ? s.substring(0, s.length() - 1) : s;
            s = s + ' from opportunity Limit 1 ';
            system.debug('--InnerQuery--'+s);
            
            SObject[] opplist = database.Query(s);
            Opportunity opp = database.Query(s);
            set<string> addSetString = new set<string>();
            for(string str : custommap.keyset()){
                addSetString = new set<string>();
                  string fields = custommap.get(str);
                   if(fields.contains(',')){
                      String[] arrTest = fields.split('\\,');
                       for(integer i = 0; i<arrTest.size();i++)
                         addSetString.add(arrTest[i]);
                    }
                else {
                    addSetString.add(fields);
                }
               nameAndFields.put(str,addSetString);
            }
            string requesturl='';
            system.debug('--nameAndFields--'+nameAndFields);
            
            Map<string, string> OppchildMap = new Map<string, string>();
                for(Schema.ChildRelationship cr : Opportunity.SObjectType.getDescribe().getChildRelationships()){
                      if( string.valueOf(cr.getChildSObject()).contains(nameSpace) &&  cr.getRelationshipName() != null){
                         string fielddifference = namespace.difference(string.valueOf(cr.getChildSObject()));
                         string objectDifference = namespace.difference(string.valueOf(cr.getRelationshipName()));
                         OppchildMap.put( objectDifference,fielddifference);
                      }
                      else {
                         OppchildMap.put( string.valueOf(cr.getRelationshipName()),string.valueof(cr.getChildSObject()));
                      }
                } 
                        
                            
                for(string item : custommap.keyset()){
                     SObject[] clist = opplist.get(0).getSObjects(item);
                     system.debug('--item--'+item);
                     
                     set<string> fields = nameAndFields.get(item);
                     Id oppLineitemId;
                    if(clist != null){
                    for(string str1 : fields){
                        string objectNameLoop = OppchildMap.get(item);
                        List<Schema.DescribeSObjectResult> describeSobjectsResultLoop = Schema.describeSObjects(new List<String>{objectNameLoop }); // this can accept list of strings, we describe only one object here
                        String objectLabelLoop = describeSobjectsResultLoop[0].getLabel();
                        Map<String, Schema.SObjectField> allFieldsLoop = describeSobjectsResultLoop[0].fields.getMap();
                        String fieldLabel = allFieldsLoop.get(str1).getDescribe().getLabel(); 
                        fieldLabel = fieldLabel.replaceAll(' ','');
                        reqEndPoint = reqEndPoint +'&'+ fieldLabel+'=';
                        for(sobject temps : clist){ 
                            if(clist.size()  > 1){
                                   String nameadca = String.valueof(temps.get(str1));
                                   nameadca = nameadca.replaceAll(' ','+');
                                   reqEndPoint = reqEndPoint+nameadca+',';
                                }
                            else{
                             String nameadca = String.valueof(temps.get(str1));
                             nameadca = nameadca.replaceAll(' ','+');
                             reqEndPoint = reqEndPoint+nameadca+'';
                            }
                        }      
                    }
                }
              }
            reqEndPoint = reqEndPoint.endsWith(',') ? reqEndPoint.substring(0, reqEndPoint.length() - 1) : reqEndPoint;
            system.debug(reqEndPoint);
              set<string> productfields = new set<string>(); 
                string pro ='Product2.';
                  string pro1 ='Product2';
                 String[] productsplitFields;
                 List<OpportunityLineItem> oppLine = new List<OpportunityLineItem>();
                if(b1 == true){
                    oppLine = Database.query('select id,'+productobject+' from '+productname +' where Opportunityid=:Oppidsearch');
                    system.debug('--oppLine--'+oppLine);
                      String[] productsplit = productobject.split('\\,');
                      for(integer i= 0; i<productsplit.size();i++){
                          string distance = pro.difference(productsplit[i]);
                          productfields.add(distance);
                      }
                }
               
                for(string str : productfields){
                    String fieldLabel = allFields.get(str).getDescribe().getLabel();    
                     fieldLabel = fieldLabel.replaceAll(' ','');
                    reqEndPoint = reqEndPoint+'&'+fieldLabel+'=';
                      for(OpportunityLineItem oppLineTemp: oppLine) {
                          SObject product = oppLineTemp.getSObject(pro1);
                           String nameadca = (String) product.get(str);
                            nameadca = nameadca.replaceAll(' ','+');
                          reqEndPoint = reqEndPoint+nameadca+',';
                      }
                }
                
            
            // End of the child object dynamic 
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            system.debug('---reqEndPoint--'+reqEndPoint);
            req.setEndpoint(reqEndPoint); 
            //req.setEndpoint(tenantURL+'/api/searches?search_type=recommendations&context=salesforce&activity=opportunities&page=1&per_page=4&thumbnails=grid%2Furl');
            req.setMethod('GET');
            req.setHeader('Authorization','Bearer '+access_token); //Adding Access Token to Authorization header
            HTTPResponse res = http.send(req);
            system.debug('----SearchResponse----'+res.getBody());
             responseMessage = String.valueOf(res.getBody());
            return (SearchResponse) System.JSON.deserialize(res.getBody(), SearchResponse.class);
        }catch(Exception e){
            isErrorOccured = true;
            typeOfException = string.valueOf( e.getStackTraceString()) + '\n Cause '+ string.valueOf( e.getCause())+' \n LineNumber '+
                              string.valueOf( e.getLineNumber()) + ' \n Error Message '+ string.valueOf( e.getMessage())+' \n TypeName '+ 
                              string.valueOf( e.getTypeName()); 
            typeOfException = typeOfException.replaceAll('\n', '');  
             typeOfException = typeOfException.replaceAll('\'', '');              
            system.debug('----exception----'+e+e.getLineNumber());
            return new SearchResponse();
        }
    }
    /*  Request  To obtain current User Favorites  */
    public static NamedListResponse obtainFavorites(String access_token, String tenantURL){
        try{
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint(tenantURL+'/api/named_lists?name=favorites');
            req.setMethod('GET');
            req.setHeader('Authorization','Bearer '+access_token); //Adding Access Token to Authorization header
            HTTPResponse res = http.send(req);
            system.debug('----NamedListResponse----'+res.getBody());
             responseMessage = String.valueOf(res.getBody());
            return (NamedListResponse) System.JSON.deserialize(res.getBody(), NamedListResponse.class);
        }catch(Exception e){
            isErrorOccured = true;
            typeOfException = string.valueOf( e.getStackTraceString()) + ' getCause '+ string.valueOf( e.getCause())+' getLineNumber '+
                              string.valueOf( e.getLineNumber()) + ' getMessage '+ string.valueOf( e.getMessage())+' getTypeName '+ 
                              string.valueOf( e.getTypeName());
            system.debug('----exception----'+e);
            typeOfException = typeOfException.replaceAll('\'', ''); 
            return new NamedListResponse();
        }
    }
    /*  Request  To create current User Favorites List, if not already present */
    public static NameListCreationResponse createFavoriteList(String access_token, String tenantURL){
        try{
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint(tenantURL+'/api/named_lists');
            req.setMethod('POST');
            req.setHeader('Authorization','Bearer '+access_token); //Adding Access Token to Authorization header
            req.setHeader('Content-Type','application/json');
            String reqBody = '{"named_list":{"name": "favorites","list_type":"system","named_list_items": []}}';
            system.debug('---reqBody---'+reqBody);
            req.setBodyAsBlob(Blob.valueOf(reqBody));
            HTTPResponse res = http.send(req);
            system.debug('----NamedListCreationResponse----'+res.getBody());
            responseMessage = String.valueOf(res.getBody());
            return (NameListCreationResponse) System.JSON.deserialize(res.getBody(), NameListCreationResponse.class);
        }catch(Exception e){
            isErrorOccured = true;
            system.debug('----exception----'+e);
            typeOfException = string.valueOf( e.getStackTraceString()) + ' getCause '+ string.valueOf( e.getCause())+' getLineNumber '+
                              string.valueOf( e.getLineNumber()) + ' getMessage '+ string.valueOf( e.getMessage())+' getTypeName '+ 
                              string.valueOf( e.getTypeName());
            typeOfException = typeOfException.replaceAll('\'', ''); 
            return new NameListCreationResponse();
        }
    }
    /*  Request  To set current course as Favorite  */
    public static Boolean setFavorite(String favoriteNamedListId, String courseId, String access_token, String tenantURL){
        try{
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint(tenantURL+'/api/named_list_items');
            req.setMethod('POST');
            req.setHeader('Authorization','Bearer '+access_token); //Adding Access Token to Authorization header
            req.setBody('named_list_item[named_list_id]='+EncodingUtil.urlEncode(favoriteNamedListId, 'UTF-8') + 
                        '&named_list_item[listable_id]='+EncodingUtil.urlEncode(courseId, 'UTF-8') + 
                        '&named_list_item[listable_type]='+EncodingUtil.urlEncode('Course', 'UTF-8'));
            HTTPResponse res = http.send(req);
            system.debug('----NamedListFavoriteResponse----'+res.getBody());
            system.debug('----NamedListFavoriteStatusCode----'+res.getStatusCode());
            responseMessage = String.valueOf(res.getBody());
            /* Request 3 : To Set as Favorite - End */
            if(res.getStatusCode() == 201){
                return true;
            }else{
                return false;
            }
        }catch(Exception e){
            isErrorOccured = true;
            typeOfException = string.valueOf( e.getStackTraceString()) + ' getCause '+ string.valueOf( e.getCause())+' getLineNumber '+
                              string.valueOf( e.getLineNumber()) + ' getMessage '+ string.valueOf( e.getMessage())+' getTypeName '+ 
                              string.valueOf( e.getTypeName());
            system.debug('----exception----'+e);
            typeOfException = typeOfException.replaceAll('\'', ''); 
            return false;
        }
    }
    /*  Request  To delete an already set favorite  */
    public static Boolean deleteFavorite(String tobeDeletedId, String access_token, String tenantURL){
        try{
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint(tenantURL+'/api/named_list_items/'+tobeDeletedId);
            req.setMethod('DELETE');
            req.setHeader('Authorization','Bearer '+access_token); //Adding Access Token to Authorization header
            HTTPResponse res = http.send(req);
            system.debug('----NamedListFavoriteDeleteResponse----'+res.getBody());
            system.debug('----NamedListFavoriteDeleteStatusCode----'+res.getStatusCode());
             responseMessage = String.valueOf(res.getBody());
            if(res.getStatusCode() == 204){
                return true;
            }else{
                return false;
            }
        }catch(Exception e){
            isErrorOccured = true;
            typeOfException = string.valueOf( e.getStackTraceString()) + ' getCause '+ string.valueOf( e.getCause())+' getLineNumber '+
                              string.valueOf( e.getLineNumber()) + ' getMessage '+ string.valueOf( e.getMessage())+' getTypeName '+ 
                              string.valueOf( e.getTypeName());
            typeOfException = typeOfException.replaceAll('\'', ''); 
            system.debug('----exception----'+e);
            return false;
        }
    }
    /*  Request  To obtain Users or Groups Matching query Term */
    public static UserOrGroups getUsersAndGroups(String queryTerm, String access_token, String tenantURL){
        try{
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint(tenantURL+'/api/audiences?match='+queryTerm);
            req.setMethod('GET');
            req.setHeader('Authorization','Bearer '+access_token); //Adding Access Token to Authorization header
            HTTPResponse res = http.send(req);
            system.debug('----UserSearchResponse----'+res.getBody());
             responseMessage = String.valueOf(res.getBody());
            return (UserOrGroups) System.JSON.deserialize(res.getBody(), UserOrGroups.class);
        }catch(Exception e){
            system.debug('----exception----'+e);
            isErrorOccured = true;
            typeOfException = string.valueOf( e.getStackTraceString()) + ' getCause '+ string.valueOf( e.getCause())+' getLineNumber '+
                              string.valueOf( e.getLineNumber()) + ' getMessage '+ string.valueOf( e.getMessage())+' getTypeName '+ 
                              string.valueOf( e.getTypeName());
            typeOfException = typeOfException.replaceAll('\'', ''); 
            return new UserOrGroups();
        }
        
    }
    /*  Request To share to User  */
    public static Boolean shareToUser(String userOrGrpId, String userName, String userType, String userComment, String courseId, String access_token, String tenantURL){
        try{
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint(tenantURL+'/api/shares');
            req.setMethod('POST');
            req.setHeader('Content-Type','application/json');
            String reqBody = '{"share":{"shared_with":[{"id":"'+EncodingUtil.urlEncode(userOrGrpId, 'UTF-8')+
                          '","name":"'+EncodingUtil.urlEncode(userName, 'UTF-8')+'","type":"'+EncodingUtil.urlEncode(userType, 'UTF-8')+
                          '"}],"comment":"'+EncodingUtil.urlEncode(userComment, 'UTF-8')+'","shareable_type":"Course","shareable_id":"'+EncodingUtil.urlEncode(courseId, 'UTF-8')+'"}}';
            system.debug('---reqBody---'+reqBody);
            req.setBodyAsBlob(Blob.valueOf(reqBody));
            req.setHeader('Authorization','Bearer '+access_token); //Adding Access Token to Authorization header
            HTTPResponse res = http.send(req);
            system.debug('----ShareResponse----'+res.getBody());
            responseMessage = String.valueOf(res.getBody());
            if(res.getStatusCode() == 201){
                system.debug('---success---');
                userComment = '';
                return true;
            }else{
                return false;
            }
        }catch(Exception e){
            isErrorOccured = true;
            typeOfException = string.valueOf( e.getStackTraceString()) + ' getCause '+ string.valueOf( e.getCause())+' getLineNumber '+
                              string.valueOf( e.getLineNumber()) + ' getMessage '+ string.valueOf( e.getMessage())+' getTypeName '+ 
                              string.valueOf( e.getTypeName());
            system.debug('----exception----'+e);
            typeOfException = typeOfException.replaceAll('\'', ''); 
            return false;
        }
    }
    
    /* This Method is used to insert the debug logs to the deubug Logs Object */
    
   public PageReference exceptionHandling(){
      if(isErrorOccured == true){
              Debug_Logs__c tempDebug = new Debug_Logs__c();
              tempDebug.Debug_DateTime__c = DateTime.now();
              tempDebug.name = 'Debug Log';
              tempDebug.Type_of_Exception__c  = typeOfException !=null ? typeOfException : 'No Exception'; 
              tempDebug.User_Name__c = currentUser;
              tempDebug.Json_Response_Kaybus__c = responseMessage;
              insert tempDebug;
              system.debug('---Debug Log---'+tempDebug);
      }
      return null;
   }
       
    /* Wrapper Class for parsing AuthResponse - Start */
    public class AuthResponse {
        public String token_type;
        public String access_token;
        public String expires_in;
    }
    /* Wrapper Class for parsing AuthResponse - End */
    
    /* Wrapper Class for parsing NamedListResponse - Start */
    public class NamedListResponse {
        public List<Named_lists> named_lists;
        public NamedListResponse(){
            this.named_lists = new List<Named_lists>();
        }
    }
    public class Named_lists {
        public String id;
        public String name;
        public String list_type;
        public List<Named_list_items> named_list_items;
        
        public Named_lists(){
            this.named_list_items = new List<Named_list_items>();
        }
    }
    public class NameListCreationResponse {
        public Named_list named_list;
    }
    public class Named_list {
        public String id;
        public String name;
        public String list_type;
        public List<Named_list_items> named_list_items;
    }
    public class Named_list_items {
        public String id;
        public String named_list_id;
        public Object position;
        public String listable_type;
        public String listable_id;
    }
    /* Wrapper Class for parsing NamedListResponse - End */
    
    /* Wrapper Class for parsing SearchResult Response - Start */
    public class SearchResponse {
        public List<Searches> searches {get; set;}
        public Meta meta {get; set;}
        public SearchResponse(){
            this.searches = new List<Searches>();
        }
    }
    public class Downloads {
        public String url {get; set;}
        public String type {get; set;}
        public String format {get; set;}
        public String filename {get; set;}
    }

    public class Searches {
        public String id {get; set;}
        public String title {get; set;}
        public String description {get; set;}
        public String article_type {get; set;}
        public String state {get; set;}
        public List<String> tags {get; set;}
        public List<String> categories {get; set;}
        public Double rating {get; set;}
        public String publisher_id {get; set;}
        public String publisher_name {get; set;}
        public String published_at {get; set;}
        //public Object expires_at {get; set;}
        public List<String> group_names {get; set;}
        public String file {get; set;}
        public Integer rating_count {get; set;}
        public User_rating user_rating {get; set;}
        public Integer step_count {get; set;}
        public Enrollment enrollment {get; set;}
        public Datetime created_at {get; set;}
        public Datetime updated_at {get; set;}
        public String content_updated_at {get; set;}
        public Boolean is_updated {get; set;}
        public Boolean is_content_updated {get; set;}
        public List<Downloads> downloads {get; set;}
        public Boolean editable {get; set;}
        public Boolean allow_sharing {get; set;}
        public Boolean allow_guest_sharing {get; set;}
        public Image image {get; set;}
        public Boolean isFavorited {get;set;}
    }
    public class Pagination {
        public Integer page {get; set;}
        public Integer total {get; set;}
        public Integer total_pages {get; set;}
        public Integer per_page {get; set;}
    }

    public class Image {
        public String id {get; set;}
        public Thumbnails thumbnails {get; set;}
    }

    public class Enrollment {
        public String id {get; set;}
        public Progress progress {get; set;}
        public String state {get; set;}
        public String created_at {get; set;}
        public String updated_at {get; set;}
        //public Object last_downloaded_at {get; set;}
        public String last_viewed_at {get; set;}
        public Integer percent_complete {get; set;}
        public Boolean downloaded_but_not_viewed {get; set;}
        public String enrollable_id {get; set;}
    }

    public class Meta {
        public List<String> facets {get; set;}
        public Pagination pagination {get; set;}
        public List<String> highlights {get; set;}
        public List<String> search_suggestions {get; set;}
        public List<String> relevance_scores {get; set;}
        public List<String> experts {get; set;}
    }

    public class Thumbnails {
        public String grid {get; set;}
    }

    public class Progress {
        //public Steps steps {get; set;}
        public String last_step {get; set;}
        public Integer percent_complete {get; set;}
    }
    public class User_rating {
        public String id {get; set;}
        public String comment {get; set;}
        public String created_at {get; set;}
        public Integer mark {get; set;}
        public String rater_class {get; set;}
        public String rater_id {get; set;}
        public Integer weight {get; set;}
    }
    /* Wrapper Class for parsing SearchResult Response - End */
    
    /* Wrapper Class for parsing UserSearch Response - Start */
    public class UserOrGroups {
        public List<Users> users;
        public List<Groups> groups;
    }
    public class Groups {
        public String id;
        public String name;
    }

    public class Users {
        public String id;
        public String first_name;
        public String last_name;
        public String email;
    }
    global class UserOrGroupDetail {
        public String id;
        public String name;
        public String type;
    }
    /* Wrapper Class for parsing UserSearch Response - End done */
}