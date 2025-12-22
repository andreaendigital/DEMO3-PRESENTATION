# Deploy Evidence

![Status](https://img.shields.io/badge/status-operational-success.svg)
![AWS](https://img.shields.io/badge/AWS-active-orange.svg)
![Azure](https://img.shields.io/badge/Azure-standby-blue.svg)


!!! info ""
    <div align="center">
    <h2 style="color: #3498DB; font-size: 1.8em; margin: 0.5em 0; font-weight: 600;">
    AWS DEPLOY
    </h2>
    </div>

=== "GITEA HOME"
   
        
    ![GITEA SCREENSHOT](assets/giteaAWS.jpeg) 

=== "USER PROFILE"

    ![GITEA SCREENSHOT](assets/profileaws.jpeg) 


=== "ENABLED REPOSITORY"    

    ![GITEA SCREENSHOT](assets/repoaws.jpeg) 


!!! info ""
    <div align="center">
    <h2 style="color: #3498DB; font-size: 1.8em; margin: 0.5em 0; font-weight: 600;">
    AZURE DEPLOY
    </h2>
    </div>    

=== "GITEA HOME"
   
    ![IP SCREENSHOT](assets/ip1.png) 
     
    ![GITEA SCREENSHOT](assets/HOME1.png) 

=== "ACCOUNT LOGIN VERIFICATION"

    ![GITEA SCREENSHOT](assets/SCREEN1.png) 

=== "CREATE ORGANIZATION AND REPOSITORY"    

    ![GITEA SCREENSHOT](assets/SCREEN2.png) 

    ![GITEA SCREENSHOT](assets/SCREEN3.png) 

=== "ENABLED REPOSITORY"    

    ![GITEA SCREENSHOT](assets/SCREEN4.png) 

!!! info ""
    <div align="center">
    <h2 style="color: #3498DB; font-size: 1.8em; margin: 0.5em 0; font-weight: 600;">
    BLOCK: 
    </h2>
    </div>        


=== "FREE TIER ERROR"    

    ![DEPLOY ERROR](assets/FREETIERERROR.png) 



!!! info ""
    <div align="center">
    <h2 style="color: #3498DB; font-size: 1.8em; margin: 0.5em 0; font-weight: 600;">
    PROGRESS AFTER BLOCKS
    </h2>
    </div>      

 === "BINLOG "    

        ![BINLOG SCREENSHOT](assets/binlogaws.png) 

=== "MASTER STATUS EVIDENCE FROM AWS"    

        ![MASTER STATUS](assets/masterstatus.png)     

=== "MESSAGES TEST AWS TO AZURE"    

        ![MASTER STATUS](assets/MESSAGESTEXT.png)    

=== "Pipeline #48 confirmed Replica"    

        ![Pipeline #48 confirmed Replica](assets/PIPELINECONFIRMATION1.png)   
        ![Pipeline #48 confirmed Replica](assets/PIPELINECONFIRMATION2.png)   

=== "VPN TUNNEL DETAILS"    

        ![Pipeline #48 confirmed Replica](assets/TUNNELDETAILS1.png)   
        ![Pipeline #48 confirmed Replica](assets/TUNNELDETAILS2.png)



- **Sync Point Identification:** The SHOW MASTER STATUS command provides the exact File and Position coordinates. This metadata is essential for the replica to know exactly where to begin data ingestion without gaps or overlaps.

- **Security & Permissions:** A dedicated user (repl_azure) is configured with the REPLICATION SLAVE privilege. Following the principle of least privilege, we avoid using the 'root' account for external cloud connections.

- **Binary Log Tracking:** The transition from file ...000060 to ...000061 confirms that the database is actively recording traceable events. These logs are the "source of truth" that will be streamed to the Azure replica.

- **Data Consistency:** Using FLUSH PRIVILEGES forces the server to reload grant tables into memory immediately. This prevents connection failures during the initial handshake between the on-premise master and the Azure environment.