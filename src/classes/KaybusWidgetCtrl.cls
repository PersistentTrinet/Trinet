/**
Author 			: 	Sriteja Prabhala
Created On 		: 	19th May, 2015
Last Modified 	: 	25th May, 2015
Purpose 		: 	1) Extension Controller for KaybusWidget Component. Used to make callouts to perform search.
					2) Also used on KaybusTab page, for initialization purpose only. As we only need the Tenant URL in that page. 
*/
global with sharing class KaybusWidgetCtrl {

    /* Config Variables Creation - Start */
    private String clientId;
    public String sectionName;
    private String clientSecret;
    public  String tenantURL 			{get;private set;}
    /* Config Variables Creation - End */
    
    /* Search Response Variables Creation - Start */
	public OpportunityRecommendationsCtrl.SearchResponse searchResp;
    public list<OpportunityRecommendationsCtrl.Searches> allsearches 	{get;set;}
    /* Search Response Variables Creation - End */
    
    /* Sharing Related Variables Creation - Start */
    public String userOrGrpId 			{get;set;}
    public String userName 				{get;set;}
    public String userType 				{get;set;}
    public String userComment 			{get;set;}
    /* Sharing Related Variables Creation - End */
    
    /* Common Variables Creation - Start */
    public Boolean hasAccess 			{get;set;} //Used to check if he has Access
    public Boolean isSuccess 			{get;set;} //Used to set the status of response
    public Boolean isFavorite 			{get;set;} //Used for Favorites, specifically
    public String courseId 				{get;set;} //Used to pass on the current CourseID
    private User curUser;
    public Integer maxPageNum 			{get;set;}
    public Integer pageNum 				{get;set;}
    public String access_token 			{get;set;}
    /* Common Variables Creation - End */
    /* Custom Getters & Setters - Start */    
    public void setSectionName (String s) {
		sectionName = s;
		system.debug('--Section Name--'+sectionName);
		performSearch(); // Performing Search Logic
	}
	    
	public String getSectionName() {
	    return sectionName;
	}
	/* Custom Getters & Setters - End */
    public KaybusWidgetCtrl(){
    	/* Initializing Variables - Start */
    	isFavorite = false;
    	isSuccess = false;
    	
        curUser = [Select Id,Name,Email from User where Id = :Userinfo.getUserId()];
        list<PermissionSetAssignment> permAssignLst = [Select Id, AssigneeID from PermissionSetAssignment where PermissionSet.Name = 'Kaybus_Permission_Set' And AssigneeID = :curUser.Id];
        if(permAssignLst != null && permAssignLst.size() > 0){
        	hasAccess = true;
        }else{
        	hasAccess = false;
        }
        
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
        /* Initializing Variables - End */
    }
    
    public void performSearch(){
        try{
        	allsearches = new list<OpportunityRecommendationsCtrl.Searches>();
        	system.debug('---pageNum---'+pageNum);
        	if(clientId != '' && clientSecret != '' && tenantURL != ''){
        		// Request 1 : To obtain Access Token
	        	OpportunityRecommendationsCtrl.AuthResponse authRep = new OpportunityRecommendationsCtrl.AuthResponse();
				authRep = OpportunityRecommendationsCtrl.obtainAccessToken(curUser.Email, clientId, clientSecret, tenantURL);
				if(authRep != null && authRep.access_token != null){ // Only entering if access_token is obtained
					access_token = authRep.access_token;	
					system.debug('----access_token---'+access_token);
					// Request 2 : To obtain Search Results
					searchResp = obtainSearchResponse(sectionName, pageNum, access_token, tenantURL);
					if(maxPageNum == 0){
						//maxPageNum = searchResp.meta != null ? searchResp.meta.pagination.total/4 : 1;
						//maxPageNum = Math.mod(searchResp.meta != null ? searchResp.meta.pagination.total : 0 ,4) > 0 ? maxPageNum + 1 : maxPageNum;
						maxPageNum = searchResp.meta != null ? searchResp.meta.pagination.total_pages : 1;
						system.debug('----maxPageNum----'+maxPageNum);
					}
					// Request 3 : To obtain Named Lists - Favorites 
					OpportunityRecommendationsCtrl.NamedListResponse nameResponse = new OpportunityRecommendationsCtrl.NamedListResponse();
					nameResponse = OpportunityRecommendationsCtrl.obtainFavorites(access_token, tenantURL);
					system.debug('---NamedLists----'+nameResponse.named_lists);
					
					/* Preparing List with Favorites - Start */
					for(OpportunityRecommendationsCtrl.Searches src : searchResp.searches){
						if(nameResponse.named_lists != null && nameResponse.named_lists.size() > 0){
							src.isFavorited = isCourseFavorited(src.id ,nameResponse.named_lists[0].named_list_items);
						}else{
							src.isFavorited = false;
						}
						allsearches.add(src);
					}
					/* Preparing List with Favorites - End */
					system.debug('----allsearches----'+allsearches);
				}
        	}
        }catch(Exception e){
            system.debug('----exception----'+e);
        }
    }
    @RemoteAction
    global static list<OpportunityRecommendationsCtrl.UserOrGroupDetail> queryUsers(String queryTerm){     
       queryTerm = queryTerm.replaceAll(' ','+');
       //String clientId = KaybusConfig__c.getAll().containsKey('ClientId') ? KaybusConfig__c.getAll().get('ClientId').Value__c : ''; 
       String clientId = '1';
       //String clientSecret = KaybusConfig__c.getAll().containsKey('ClientSecret') ? KaybusConfig__c.getAll().get('ClientSecret').Value__c : '';
       String clientSecret = 'secret'; 
       String tenantURL = KaybusConfig__c.getAll().containsKey('Tenant') ? KaybusConfig__c.getAll().get('Tenant').Value__c : '';  
       
       String access_token = '';
       
       User curUser = [Select Id,Name,Email from User where Id = :Userinfo.getUserId()];
       list<OpportunityRecommendationsCtrl.UserOrGroupDetail> options = new list<OpportunityRecommendationsCtrl.UserOrGroupDetail>();
       
       if(clientId != '' && clientSecret != '' && tenantURL != ''){
    		// Request 1 : To obtain Access Token
        	OpportunityRecommendationsCtrl.AuthResponse authRep = new OpportunityRecommendationsCtrl.AuthResponse();
			authRep = OpportunityRecommendationsCtrl.obtainAccessToken(curUser.Email, clientId, clientSecret, tenantURL);
						
			if(authRep != null && authRep.access_token != null){ // Only entering if access_token is obtained
				system.debug('----access_token---'+authRep.access_token);
				access_token = authRep.access_token;
				// Request 2 : To obtain Search Results
				OpportunityRecommendationsCtrl.UserOrGroups allUsersOrGrps = new OpportunityRecommendationsCtrl.UserOrGroups();
				allUsersOrGrps = OpportunityRecommendationsCtrl.getUsersAndGroups(queryTerm, access_token, tenantURL);
				
				/* Preparing List with Users and Groups - Start */
				for(OpportunityRecommendationsCtrl.Users usr: allUsersOrGrps.users){
					OpportunityRecommendationsCtrl.UserOrGroupDetail ugOpt = new OpportunityRecommendationsCtrl.UserOrGroupDetail();
					ugOpt.id = usr.id;
					ugOpt.name = usr.last_name +', '+ usr.first_name + ' - ' + usr.email;
					ugOpt.type = 'User';
					options.add(ugOpt);
				}
				for(OpportunityRecommendationsCtrl.Groups usr: allUsersOrGrps.groups){
					OpportunityRecommendationsCtrl.UserOrGroupDetail ugOpt = new OpportunityRecommendationsCtrl.UserOrGroupDetail();
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
    public void favouriteItem(){
        try{
        	isSuccess = false;
        	system.debug('courseId----'+courseId);
        	if(clientId != '' && clientSecret != '' && tenantURL != ''){
        		// Request 1 : To obtain Access Token
	        	OpportunityRecommendationsCtrl.AuthResponse authRep = new OpportunityRecommendationsCtrl.AuthResponse();
				authRep = OpportunityRecommendationsCtrl.obtainAccessToken(curUser.Email, clientId, clientSecret, tenantURL);
							
				if(authRep != null && authRep.access_token != null){ // Only entering if access_token is obtained
					system.debug('----access_token---'+authRep.access_token);
					access_token = authRep.access_token;
					// Request 2 : To obtain Named Lists - Favorites 
					OpportunityRecommendationsCtrl.NamedListResponse nameResponse = new OpportunityRecommendationsCtrl.NamedListResponse();
					nameResponse = OpportunityRecommendationsCtrl.obtainFavorites(access_token, tenantURL);
					system.debug('---NamedLists----'+nameResponse.named_lists);
					
					String favoriteNamedListId = '';
					if(nameResponse.named_lists != null && nameResponse.named_lists.size() > 0){
						favoriteNamedListId = nameResponse.named_lists[0].id;
					}else{
						// Request 2.1 : To Create Named Lists - Favorites 
						OpportunityRecommendationsCtrl.NameListCreationResponse nameListResponse = new OpportunityRecommendationsCtrl.NameListCreationResponse();
						nameListResponse = OpportunityRecommendationsCtrl.createFavoriteList(access_token, tenantURL);
						favoriteNamedListId = nameListResponse.named_list.id;
					}
					system.debug('----favoriteNamedListId---'+favoriteNamedListId);
					if(!isFavorite){
						// Request 3 : To Set as Favorite 
						isSuccess = OpportunityRecommendationsCtrl.setFavorite(favoriteNamedListId, courseId, access_token, tenantURL);
						for(OpportunityRecommendationsCtrl.Searches srch : allsearches){
							if(srch.id.equals(courseId)){
								system.debug('----Found----'+srch);
								srch.isFavorited = true;
							}
						}
					}else{
						String tobeDeletedId = '';
						for(OpportunityRecommendationsCtrl.Named_list_items nameLstItem : nameResponse.named_lists[0].named_list_items){
							if(nameLstItem.listable_id.equals(courseId)){
								tobeDeletedId = nameLstItem.id;
							}
						}
						// Request 3 : To Delete Favorite
						isSuccess = OpportunityRecommendationsCtrl.deleteFavorite(tobeDeletedId, access_token, tenantURL);
						for(OpportunityRecommendationsCtrl.Searches srch : allsearches){
							if(srch.id.equals(courseId)){
								system.debug('----Found----'+srch);
								srch.isFavorited = false;
							}
						}
					}
					
				}
        	}
        	system.debug('---allsearches--'+allsearches);
        }catch(Exception e){
            system.debug('----exception----'+e);
        }
    }    
    public Boolean isCourseFavorited(String courseId, List<OpportunityRecommendationsCtrl.Named_list_items> named_list_items){
    	for(OpportunityRecommendationsCtrl.Named_list_items lstItem : named_list_items){
    		if(courseId.equalsIgnoreCase(lstItem.listable_id)){
    			return true;
    		}
    	}
    	return false;
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
	        	OpportunityRecommendationsCtrl.AuthResponse authRep = new OpportunityRecommendationsCtrl.AuthResponse();
				authRep = OpportunityRecommendationsCtrl.obtainAccessToken(curUser.Email, clientId, clientSecret, tenantURL);
							
				if(authRep != null && authRep.access_token != null){ // Only entering if access_token is obtained
					system.debug('----access_token---'+authRep.access_token);
					access_token = authRep.access_token;
					// Request 2 : To Post a Share
					isSuccess = OpportunityRecommendationsCtrl.shareToUser(userOrGrpId, userName, userType, userComment, courseId, access_token, tenantURL);
				}
        	}
        	system.debug('---allsearches--'+allsearches);
        }catch(Exception e){
            system.debug('----exception----'+e);
        }
    }
    /*  Request  To obtain Search Response  */
    public static OpportunityRecommendationsCtrl.SearchResponse obtainSearchResponse(String sectionName, Integer pageNum, String access_token, String tenantURL){
    	try{
    		Http http = new Http();
	    	HttpRequest req = new HttpRequest();
    		String reqEndPoint = '';
			if(sectionName.equalsIgnoreCase('MySalesOpportunities')){
				reqEndPoint = tenantURL+'/api/searches?search_type=recommendations&context=sales&activity=opportunities&page='+pageNum+'&per_page=4&max_results=20&thumbnails=grid%2Furl';
			}else if(sectionName.equalsIgnoreCase('MyCampaigns')){
				reqEndPoint = tenantURL+'/api/searches?search_type=campaigns&page='+pageNum+'&per_page=4&max_results=20&thumbnails=grid%2Furl';
			}else if(sectionName.equalsIgnoreCase('SharedWithMe')){
				reqEndPoint = tenantURL+'/api/searches?search_type=shares&page='+pageNum+'&per_page=4&max_results=20&thumbnails=grid%2Furl';
			}
			system.debug('---reqEndPoint--'+reqEndPoint);
			req.setEndpoint(reqEndPoint); 
			req.setMethod('GET');
			req.setHeader('Authorization','Bearer '+access_token); //Adding Access Token to Authorization header
			HTTPResponse res = http.send(req);
			system.debug('----SearchResponse----'+res.getBody());
			
			return (OpportunityRecommendationsCtrl.SearchResponse) System.JSON.deserialize(res.getBody(), OpportunityRecommendationsCtrl.SearchResponse.class);
    	}catch(Exception e){
    		system.debug('----exception----'+e);
    		return new OpportunityRecommendationsCtrl.SearchResponse();
    	}
    }
}