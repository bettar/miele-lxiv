//
//  ©Alex Bettarini -- all rights reserved
//  License GPLv3.0 -- see License File
//  Created by Alex Bettarini on 12 May 2015
//

#include "dcmtk/dcmqrdb/dcmqrsrv.h"

class DcmQueryRetrieveOsiriSCP : public DcmQueryRetrieveSCP
{
public:
    
    /** constructor
     *  @param config SCP configuration facility
     *  @param options SCP configuration options
     *  @param factory factory object used to create database handles
     */
    DcmQueryRetrieveOsiriSCP(
                        const DcmQueryRetrieveConfig& config,
                        const DcmQueryRetrieveOptions& options,
                        const DcmQueryRetrieveDatabaseHandleFactory& factory,
                        const DcmAssociationConfiguration& associationConfiguration,
                        DcmTLSOptions& tlsOptions);
    
    void writeErrorMessage( const char *str);
    OFCondition handleAssociation(T_ASC_Association * assoc, OFBool correctUIDPadding);

    virtual
    OFCondition getSCP(T_ASC_Association * assoc,
                       T_DIMSE_C_GetRQ * request,
                       T_ASC_PresentationContextID presID,
                       DcmQueryRetrieveDatabaseHandle& dbHandle);
    
    virtual
    OFCondition storeSCP(T_ASC_Association * assoc,
                         T_DIMSE_C_StoreRQ * req,
                         T_ASC_PresentationContextID presId,
                         DcmQueryRetrieveDatabaseHandle& dbHandle,
                         OFBool correctUIDPadding);
    
    //char imageFileName[MAXPATHLEN+1];

private:
    
    int index;
};
