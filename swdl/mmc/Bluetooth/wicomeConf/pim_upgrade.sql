CREATE TABLE IF NOT EXISTS navigation (
navUniqueId INTEGER PRIMARY KEY ,
formattedName TEXT NOT NULL ,
data NAME TEXT NOT NULL,
lat  TEXT,
lon  TEXT,
navId INTEGER );

CREATE TABLE IF NOT EXISTS SmsTemplates (
smsTemplateId INTEGER PRIMARY KEY ,
smsBody TEXT NOT NULL ,
timeStamp TEXT NOT NULL );

CREATE TABLE IF NOT EXISTS EmergencyNumbers (
  contactsId  INTEGER PRIMARY KEY,
  familyName TEXT NULL ,
  givenName TEXT NULL ,
  formattedName TEXT NULL ,
  telephoneNumber TEXT NULL);