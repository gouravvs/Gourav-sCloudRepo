Select sd.database_id as 'DB_ID' ,
sd.name as 'DatabaseName',
sd.state_desc as'State',
sd.compatibility_level as 'Compatibility',
sd.COLLATION_name as 'COLLATION',
sd.recovery_model_desc as 'RecoveryModel',
CASE
    WHEN sd.is_encrypted ='0' THEN 'NOT ENCRYPTED'
    WHEN sd.is_encrypted ='1' THEN 'ENCRYPTED/ ENCRYPTING'
    END
    as 'EncryptionStatus'
from sys.databases sd