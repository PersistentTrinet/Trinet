/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an organization are executed whenever Apex code is deployed
 * to a production organization to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production organization. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the organization size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest(seeAllData=false)
public with sharing class KaybusWidgetCtrlTest implements HttpCalloutMock{
	public static Opportunity opp;
	public static User newUser;
	public static Boolean isCreated;
	public static void prepareTestData(){
		Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator']; 
      	newUser = new User(Alias = 'standt', Email='standarduser@testorg.com', 
      					EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', 
     				 	LocaleSidKey='en_US', ProfileId = p.Id, 
      					TimeZoneSidKey='America/Los_Angeles', UserName='testUser@kaybus.testorg');
      	system.runAs(newUser){ 				
			if(!KaybusConfig__c.getAll().containsKey('ClientId')){
				KaybusConfig__c clientIdConf = new KaybusConfig__c();
				clientIdConf.Name = 'ClientId';
				clientIdConf.Value__c = 'Dummy';
				insert clientIdConf;
			}
			if(!KaybusConfig__c.getAll().containsKey('ClientSecret')){
				KaybusConfig__c clientSecConf = new KaybusConfig__c();
				clientSecConf.Name = 'ClientSecret';
				clientSecConf.Value__c = 'Dummy';
				insert clientSecConf;
			}
			if(!KaybusConfig__c.getAll().containsKey('Tenant')){
				KaybusConfig__c tenetConfig = new KaybusConfig__c();
				tenetConfig.Name = 'Tenant';	
				tenetConfig.Value__c = 'https://xyz.kaybus.com';
				insert tenetConfig;
			}
      	}
      	PermissionSet perSet = new PermissionSet();
      	list<PermissionSet> perSetLst = [Select Id from PermissionSet where name = 'Kaybus_Permission_Set'];
      	if(perSetLst != null && perSetLst.size() > 0){
      		perSet = perSetLst[0];
      	}else{
      		perSet.Name = 'Kaybus_Permission_Set';
			insert perSet;
      	}
		
		PermissionSetAssignment pa = new PermissionSetAssignment();
		list<PermissionSetAssignment> perSetAssignLst = [Select Id from PermissionSetAssignment where PermissionSet.Name = 'Kaybus_Permission_Set' 
														 and AssigneeID = :UserInfo.getUserId()];
		if(perSetAssignLst != null && perSetAssignLst.size() > 0){
      		pa = perSetAssignLst[0];
      	}else{
			pa.AssigneeID = UserInfo.getUserId();
			pa.PermissionSetId = perSet.Id;
			insert pa;
		}
      	isCreated = false;
	}
    public static testMethod void myUnitTest(){
        // TO DO: implement unit test
        prepareTestData(); 
        Test.startTest();
        
     	Test.setMock(HttpCalloutMock.class, new KaybusWidgetCtrlTest());
     	
     	isCreated = true;
        KaybusWidgetCtrl kayTabObj = new KaybusWidgetCtrl();
        kayTabObj.setSectionName('MySalesOpportunities');
        system.assert(kayTabObj.allsearches != null);
        system.assertEquals(kayTabObj.tenantUrl, 'https://xyz.kaybus.com');
        
        kayTabObj.courseId = 'dummyCourseId';
        isCreated = false;
        kayTabObj.favouriteItem();
        kayTabObj.isFavorite = true;
        kayTabObj.favouriteItem();
        
        isCreated = true;
        kayTabObj.favouriteItem();
        kayTabObj.isFavorite = true;
        kayTabObj.favouriteItem();
        
        kayTabObj.userOrGrpId = 'userId';
        kayTabObj.userName = 'test asus';
        kayTabObj.userType = 'User';
        kayTabObj.userComment = 'Shared';
        kayTabObj.shareContent();
        
        list<OpportunityRecommendationsCtrl.UserOrGroupDetail> usersLst =  KaybusWidgetCtrl.queryUsers('abc');
        Test.stopTest();
    }
    
    public HTTPResponse respond(HTTPRequest req){   
        HttpResponse res = new HttpResponse();
        String tenantURL = KaybusConfig__c.getAll().containsKey('Tenant') ? KaybusConfig__c.getAll().get('Tenant').Value__c : 'https://xyz.kaybus.com';
        
        system.assertEquals(tenantURL, 'https://xyz.kaybus.com');
        
        if(req.getEndpoint().contains(tenantURL + '/policy/oauth/access_token')){
            String response='{"token_type":"bearer","access_token":"accToken","expires_in":"9600"}';
            res.setHeader('Content-Type', 'application/json');
            res.setBody(response);
            res.setStatusCode(200);
        }else if(req.getEndpoint().contains(tenantURL + '/api/searches')){
            String response='{"searches":[{"id":"dummyCourseId","title":"Dummy Title","description":"Dummy Desc.","article_type":"courses","state":"active","tags":["Newsletter"],"categories":["Newsletter"],"rating":null,"publisher_id":"5493f5499a6bf4b03a000029","publisher_name":"Raghu Srinivasan","published_at":"2015-02-03T11:01:55+00:00","expires_at":null,"group_names":[],"file":"fileUrl","rating_count":0,"user_rating":{"_id":"ratingId","comment":"My Comment","created_at":"2015-05-04T04:41:12Z","mark":4,"rater_class":"User","rater_id":"userId","weight":1},"step_count":0,"enrollment":{"id":"enrolId","progress":{"steps":{},"last_step":null,"percent_complete":0},"state":"viewed","created_at":"2015-05-07T06:04:19Z","updated_at":"2015-05-07T06:15:42Z","last_downloaded_at":"2015-05-07T06:15:42+00:00","last_viewed_at":null,"percent_complete":0,"downloaded_but_not_viewed":true,"enrollable_id":"enrolId"},"created_at":"2015-02-03T11:01:55Z","updated_at":"2015-04-16T09:31:39Z","content_updated_at":"2015-02-03T11:01:55+00:00","is_updated":null,"is_content_updated":null,"downloads":[{"url":"courseUrl","type":"Asset","format":"original"},{"url":"zipURL","type":"Course","format":"zip"}],"editable":false,"allow_sharing":true,"allow_guest_sharing":false,"image":{"id":"imgId","thumbnails":{"grid":"gridURL"}}}],"meta":{"facets":[],"pagination":{"page":1,"total":100,"total_pages":25,"per_page":4},"highlights":[],"search_suggestions":[],"relevance_scores":[],"experts":[]}}';
            res.setHeader('Content-Type', 'application/json');
            res.setBody(response);
            res.setStatusCode(200);
        }else if(req.getEndpoint().contains(tenantURL + '/api/named_lists?name=favorites')){
        	String response = '';
        	if(!isCreated){
        		response = '{"named_lists":[]}';
        	}else{
        		response='{"named_lists":[{"id":"nameListId","name":"favorites","list_type":"system","named_list_items":[{"id":"nameListItemId","named_list_id":"nameListId","position":null,"listable_type":"Course","listable_id":"dummyCourseId"}]}]}';
        	}
            res.setHeader('Content-Type', 'application/json');
            res.setBody(response);
            res.setStatusCode(200);
        }else if(req.getEndpoint().contains(tenantURL+'/api/named_lists')){
            String response='{"named_list":{"id":"nameListId","name":"favorites","list_type":"system","named_list_items":[]}}';
            res.setHeader('Content-Type', 'application/json');
            res.setBody(response);
            res.setStatusCode(201);
        } else if(req.getEndpoint().equals(tenantURL + '/api/named_list_items') && req.getMethod().equals('POST')){
            String response='{"named_list_item":{"id":"nameListItemId2","named_list_id":"nameListId","position":null,"listable_type":"Course","listable_id":"dummyCourseId"}}';
            res.setHeader('Content-Type', 'application/json');
            res.setBody(response);
            res.setStatusCode(201);
        }else if(req.getEndpoint().contains(tenantURL + '/api/named_list_items/') && req.getMethod().equals('DELETE')){
            String response='';
            res.setHeader('Content-Type', 'application/json');
            res.setBody(response);
            res.setStatusCode(204);
        }else if(req.getEndpoint().contains(tenantURL+'/api/audiences?match=')){
            String response='{"users":[{"id":"userId","first_name":"test","last_name":"asus","email":"asus@kaybus.test"}],"groups":[{"id":"grpId","first_name":"test","last_name":"group","email":"group@kaybus.test"}]}';
            res.setHeader('Content-Type', 'application/json');
            res.setBody(response);
            res.setStatusCode(200);
        }else if(req.getEndpoint().contains(tenantURL+'/api/shares')){
            String response='{"share":{"id":"shareID","shareable_id":"dummyCourseId","shareable_type":"Course","shared_with":[{"id":"userId","type":"User","name":"test+asus"}],"comment":null}}';
            res.setHeader('Content-Type', 'application/json');
            res.setBody(response);
            res.setStatusCode(201);
        } 
        
        return res;
    }

}