use testdb
go
/* Function to clear Non Numeric Character in Phone No */
drop function if exists ClearNonNumericCharacters
go 

create function ClearNonNumericCharacters(@str nvarchar(max))
returns nvarchar(max)
as
begin
 while patindex('%[^0-9]%', @str) > 0
  set @str = stuff(@str, patindex('%[^0-9]%', @str), 1, '')
 return @str
end
go 
/* Function to clear Numeric Character in Caselabel */

drop function if exists ClearNumericCharacters
go
create function ClearNumericCharacters(@str nvarchar(max))
returns nvarchar(max)
as
begin
 while patindex('%[^A-Z]%', @str) > 0
  set @str = stuff(@str, patindex('%[^A-Z]%', @str), 1, '')
 return @str
end
go
/*-----------------------------------------------------
CaseI: Duplication based on firstname, lastname,emailaddress and zip code.
-------------------------------------------------------*/
Drop table if exists #temp_CaseI_duplication
go 
select identity(int,1,1) as CaseIID, firstname+lastname+emailaddress+zip as combination
into #temp_CaseI_duplication
from [dbo].[SampleData]
where firstname+lastname+emailaddress+zip <> ''
group by firstname+lastname+emailaddress+zip
having count(*)>1

create index idx_dup on #temp_CaseI_duplication(combination)
go
Drop table if exists Duplicates
go 
select 'CaseI' + right('0000000' + convert(nvarchar(50),b.CaseIID),7) as CaseLabel, 
a.firstname + a.lastname + a.emailaddress + a.zip as DuplicateKey, a.*
into Duplicates
from [dbo].[SampleData] a
inner join #temp_CaseI_duplication b
on b.combination = a.firstname + a.lastname + a.emailaddress + a.zip

select top 100 * from Duplicates
where DuplicateKey = 'JoshPitrejosh.pitre@compass.com30305'

/*-----------------------------------------------------
CaseII: Duplication based on Email Address.
-------------------------------------------------------*/
Drop table if exists #temp_CaseII_duplication
go
select identity(int,1,1) as CaseIID, emailaddress as combination 
into #temp_CaseII_duplication
from[dbo].[SampleData]
where emailaddress is not null
group by emailaddress
having count(*)>1	
go
create index idx_dup on #temp_CaseII_duplication(combination)
go
alter table Duplicates alter column CaseLabel varchar(100)
go
insert into Duplicates
select 'CaseII' + right('0000000' + convert(nvarchar(50),b.CaseIID),7) as CaseLabel, 
a.emailaddress as DuplicateKey, a.*
from [dbo].[SampleData] a
inner join #temp_CaseII_duplication b
on b.combination = a.emailaddress

select top 100 * from Duplicates 
where CaseLabel like '%CaseII%'
and DuplicateKey = 'fchavez16@gmail.com'

/*-----------------------------------------------------
CaseIII: Duplication based on typos in First Name.
-------------------------------------------------------*/
Drop table if exists #temp_CaseIII_duplication
go
select identity(int,1,1) as CaseIID,LastName+left(FirstName,5) as combination
into #temp_CaseIII_duplication
from [dbo].[SampleData]
group by LastName+left(FirstName,5)
having count(distinct FirstName)>1
go
create index idx_dup on #temp_CaseIII_duplication(combination)
go
insert into Duplicates
select 'CaseIII' + right('0000000' + convert(nvarchar(50),b.CaseIID),7) as CaseLabel, 
b.combination as DuplicateKey, a.*
from [dbo].[SampleData] a
inner join #temp_CaseIII_duplication b
on b.combination = a.LastName+left(a.FirstName,5)

select top 100 * from Duplicates 
where CaseLabel like '%CaseIII%'
and DuplicateKey = 'JohnsonShawn'

/*-----------------------------------------------------
CaseIV: Duplication based on typos in Email Address
-------------------------------------------------------*/
Drop table if exists #temp_CaseIV_duplication
go 
select identity(int,1,1) as CaseIID,left(EmailAddress,15) as combination
into #temp_CaseIV_duplication
from [dbo].[SampleData]
group by left(EmailAddress,15)
having count(distinct EmailAddress)>1

create index idx_dup on #temp_CaseIV_duplication(combination)

insert into Duplicates
select 'CaseIV' + right('0000000' + convert(nvarchar(50),b.CaseIID),7) as CaseLabel, 
b.combination as DuplicateKey, a.*
from [dbo].[SampleData] a
inner join #temp_CaseIV_duplication b
on b.combination = left(EmailAddress,15)

select * from Duplicates
where CaseLabel like '%CaseIV%'
and DuplicateKey = 'linda.williams@'

/*-----------------------------------------------------
CaseV: Duplication based on typos in Company name. We will firstly
apply rollup and then will look for duplication
-------------------------------------------------------*/

/* Adding column Rollup_Company name to duplicate table */
alter table [dbo].[Duplicates] add Rollup_Company varchar(max)

drop table if exists Copy_ActualData
go 
select * into Copy_ActualData 
from [dbo].[SampleData]
go
alter table Copy_ActualData add Rollup_Company varchar(max)
go
drop table if exists #temp_Company_Rollup
go 
select distinct Company 
into #temp_Company_Rollup
from [dbo].[SampleData]
where left(Company,15)+cast(len(Company) as varchar) in
(
select left(Company,15)+cast(max(len(Company)) as varchar)
from [dbo].[SampleData]
group by left(Company,15)
having count(distinct Company)>1
)
go 

update b 
set b.Rollup_Company = coalesce(a.Company,b.Company) 
from  #temp_Company_Rollup a 
join [dbo].Copy_ActualData b 
on left(a.Company,15) = left(b.Company,15)

/* check for Coldwell Banker Residential Brokerage*/
select distinct Company from 
[dbo].Copy_ActualData
where Rollup_Company = 'Coldwell Banker Residential Brokerage'

/*
select distinct Company,Rollup_Company 
from [dbo].Copy_ActualData
*/
update a 
set Rollup_Company = a.Company 
from  [dbo].Copy_ActualData a 
where a.Rollup_Company is null

/*
select distinct Rollup_Company,Company from [dbo].Copy_ActualData
*/
drop table if exists #temp_CaseV_duplication
go
select identity(int,1,1) as CaseIID,Rollup_Company+FullName as combination
into #temp_CaseV_duplication
from [dbo].Copy_ActualData
group by Rollup_Company+FullName
having count(*)>1

insert into Duplicates
select 'CaseV' + right('0000000' + convert(nvarchar(50),b.CaseIID),7) as CaseLabel, 
b.combination as DuplicateKey, a.*
from [dbo].Copy_ActualData a
inner join #temp_CaseV_duplication b
on b.combination = a.Rollup_Company+a.FullName

update a 
set Rollup_Company = a.Company 
from Duplicates a 
where Rollup_Company is null

select * from
Duplicates
where CaseLabel like '%CaseV%'
and DuplicateKey = 'Virtual PropertiesDaniel Kramlich'

/*-----------------------------------------------------
CaseVI: Duplication based on typos in Address. We will firstly
apply rollup and then will look for duplication
-------------------------------------------------------*/

drop table if exists #temp_MaxLength_Address
go
select distinct a.Address
into #temp_MaxLength_Address
from [dbo].[SampleData] a
where left(Address,15)+cast(len(Address) as varchar) in
(
select left(Address,15)+cast(max(len(Address)) as varchar)
from [dbo].[SampleData]
group by left(Address,15)
having count(distinct Address)>1
)
go
alter table [dbo].[Copy_ActualData] add Rollup_Address varchar(max)
go
update b 
set Rollup_Address = coalesce(a.Address, b.Address)
from  #temp_MaxLength_Address a
join [dbo].[Copy_ActualData] b 
on left(a.Address,15) = left(b.Address,15)

select distinct Address,Rollup_Address
from [dbo].[Copy_ActualData]
where Rollup_Address = '1014 S Charles St;Ste. A'

update a 
set Rollup_Address = Address 
from [dbo].[Copy_ActualData] a 
where a.Rollup_Address is null

select distinct top 100  Address,Rollup_Address
from [dbo].[Copy_ActualData]
where Rollup_Address = '11 Dupont Circle NW, Suite 650'
order by 2 

drop table if exists #temp_CaseVI_duplication
go
select identity(int,1,1) as CaseIID,FullName+Rollup_Address as combination
into #temp_CaseVI_duplication
from [dbo].[Copy_ActualData]
group by FullName+Rollup_Address
having count(*)>1

alter table [dbo].[Duplicates] add Rollup_Address varchar(max)
go
insert into Duplicates
select 'CaseVI' + right('0000000' + convert(nvarchar(50),b.CaseIID),7) as CaseLabel, 
b.combination as DuplicateKey, a.*
from [dbo].Copy_ActualData a
inner join #temp_CaseVI_duplication b
on b.combination = a.FullName+a.Rollup_Address

select * from Duplicates 
where CaseLabel like '%CaseVI%'
and DuplicateKey = 'Terri Sperry2296 Henderson Mill Rd NE, #116'

/*-----------------------------------------------------
CaseVII: Duplication based on FullName and Phone No
-------------------------------------------------------*/
/* Update Script to remove Non Numeric Character in Phone No */

update s
set phone = dbo.ClearNonNumericCharacters(Phone)
from [dbo].[Copy_ActualData] as s 
where phone is not null
go
Drop table if exists #temp_CaseVII_duplication 
go
select identity(int,1,1) as CaseIID,Phone+FullName as combination 
into #temp_CaseVII_duplication
from [dbo].[SampleData]
where Phone not like '%0%'
and Phone <>''
group by Phone+FullName 
having count(*)>1
go 
insert into Duplicates
select 'CaseVII' + right('0000000' + convert(nvarchar(50),b.CaseIID),7) as CaseLabel, 
b.combination as DuplicateKey, a.*
from [dbo].Copy_ActualData a
inner join #temp_CaseVII_duplication b
on b.combination = a.Phone+a.FullName
go 
select * from Duplicates
where CaseLabel like '%CaseVII%'
and DuplicateKey = '6785172197Alizia Stargell'

/*-----------------------------------------------------
CaseVIII: Duplication based on FullName
-------------------------------------------------------*/
Drop table if exists #temp_CaseVIII_duplication 
go
select identity(int,1,1) as CaseIID,FullName as combination 
into #temp_CaseVIII_duplication
from [dbo].[SampleData] 
group by FullName
having count(*) > 1
go 
insert into Duplicates
select 'CaseVIII' + right('0000000' + convert(nvarchar(50),b.CaseIID),7) as CaseLabel, 
b.combination as DuplicateKey, a.*
from [dbo].Copy_ActualData a
inner join #temp_CaseVIII_duplication b
on b.combination = a.FullName

select * from Duplicates
where CaseLabel like '%CaseVIII%'
and DuplicateKey = 'Doris Poulsen'

/*-----------------------------------------------------
CaseIX: Duplication based on Email Domain
-------------------------------------------------------*/
alter table [dbo].Copy_ActualData add Email_Domain varchar(200)
alter table [dbo].[Duplicates] add Email_Domain varchar(200)

go
update a 
set Email_Domain = substring(emailaddress,charindex('@',emailaddress)+1,len(emailaddress)) 
from [dbo].Copy_ActualData a
where EmailAddress is not null

Drop table if exists #temp_CaseIX_duplication 
go

select identity(int,1,1) as CaseIID,
Email_Domain+FullName as combination
into #temp_CaseIX_duplication
from [dbo].Copy_ActualData
group by Email_Domain+FullName
having count(*)>1
go

insert into Duplicates
select 'CaseIX' + right('0000000' + convert(nvarchar(50),b.CaseIID),7) as CaseLabel, 
b.combination as DuplicateKey, a.*
from [dbo].Copy_ActualData a
inner join #temp_CaseIX_duplication b
on b.combination = a.Email_Domain+a.FullName

go 
/*-----------------------------------------------------
CaseX: Duplication based on Domain
-------------------------------------------------------*/
/*
select distinct emailaddress,
case when charindex('.',emailaddress,charindex('@',emailaddress))-charindex('@',emailaddress)>0 and charindex('@',emailaddress)>0 then substring(emailaddress,charindex('@',emailaddress)+1,charindex('.',emailaddress,charindex('@',emailaddress))-charindex('@',emailaddress)-1) else emailaddress end
from [dbo].Copy_ActualData
where emailaddress is not null
*/
go 
alter table [dbo].Copy_ActualData add domain varchar(200)
alter table [dbo].[Duplicates] add domain varchar(200)
go

update a 
set domain = case when charindex('.',emailaddress,charindex('@',emailaddress))-charindex('@',emailaddress)>0 and charindex('@',emailaddress)>0 then substring(emailaddress,charindex('@',emailaddress)+1,charindex('.',emailaddress,charindex('@',emailaddress))-charindex('@',emailaddress)-1) else emailaddress end
from [dbo].Copy_ActualData a 
where emailaddress is not null

/*
select * from [dbo].Copy_ActualData
where domain+FullName in (
select domain+FullName from [dbo].Copy_ActualData a 
group by domain+FullName 
having count(distinct Email_Domain)>1
)
order by domain+FullName
*/
Drop table if exists #temp_CaseX_duplication 
go
select identity(int,1,1) as CaseIID,domain+FullName as combination
into #temp_CaseX_duplication 
from [dbo].Copy_ActualData a 
group by domain+FullName 
having count(distinct Email_Domain)>1
go

insert into Duplicates
select 'CaseX' + right('0000000' + convert(nvarchar(50),b.CaseIID),7) as CaseLabel, 
b.combination as DuplicateKey, a.*
from [dbo].Copy_ActualData a
inner join #temp_CaseX_duplication b
on b.combination = a.domain+a.FullName

/*
select * from Duplicates
where CaseLabel like 'CaseX%' 
order by 2
*/
/*-----------------------------------------------------
CaseXI: Duplication based on Email Address (left character before @) 
and Full Name
-------------------------------------------------------*/
go
alter table [dbo].Copy_ActualData add Emailbefore@ varchar(200)
go
alter table [dbo].[Duplicates] add Emailbefore@ varchar(200)
go
update a 
set Emailbefore@ = substring(EmailAddress,1,charindex('@',EmailAddress)-1)
from [dbo].Copy_ActualData a
where EmailAddress is not null
and charindex('@',EmailAddress) >0

Drop table if exists #temp_CaseXI_duplication 
go

select  identity(int,1,1) as CaseIID,
Emailbefore@+FullName as Combination
into #temp_CaseXI_duplication 
from [dbo].Copy_ActualData
where EmailAddress is not null
and charindex('@',EmailAddress) >0
group by Emailbefore@+FullName
having count(distinct EmailAddress)>1

insert into Duplicates
select 'CaseXI' + right('0000000' + convert(nvarchar(50),b.CaseIID),7) as CaseLabel, 
b.combination as DuplicateKey, a.*
from [dbo].Copy_ActualData a
inner join #temp_CaseXI_duplication b
on b.combination = a.Emailbefore@+a.FullName


/*
----------------------------------------------------------- 
Summary Sheet 
-------------------------------------------------------------*/
alter table Duplicates add Cases varchar(200)
go

update s
set Cases = dbo.ClearNumericCharacters(Caselabel)
from [dbo].[Duplicates] as s 
go

Declare @countTotal int

select @countTotal = count(*) from  [dbo].[SampleData]
print(cast(@countTotal*1.0 as numeric(19,1)))

select 
count(*) as Count,
concat(left(count(*)/cast(@countTotal*1.0 as numeric(19,2)) *100,4),'%') as 'Percentage',
'CaseI'
from [dbo].Duplicates
where Cases = 'CaseI'
Union 
select 
count(*) as Count,
concat(left(count(*)/cast(@countTotal*1.0 as numeric(19,2)) *100,4),'%') as 'Percentage',
'CaseII' as Cases
from [dbo].Duplicates
where Cases = 'CaseII'
Union 
select 
count(*) as Count,
concat(left(count(*)/cast(@countTotal*1.0 as numeric(19,2)) *100,4),'%') as 'Percentage',
'CaseIII' as Cases
from [dbo].Duplicates
where Cases = 'CaseIII'
Union 
select 
count(*) as Count,
concat(left(count(*)/cast(@countTotal*1.0 as numeric(19,2)) *100,4),'%') as 'Percentage',
'CaseIV' as Cases
from [dbo].Duplicates
where Cases = 'CaseIV'
Union 
select 
count(*) as Count,
concat(left(count(*)/cast(@countTotal*1.0 as numeric(19,2)) *100,4),'%') as 'Percentage',
'CaseV' as Cases
from [dbo].Duplicates
where Cases = 'CaseV'
Union 
select 
count(*) as Count,
concat(left(count(*)/cast(@countTotal*1.0 as numeric(19,2)) *100,4),'%') as 'Percentage',
'CaseVI' as Cases
from [dbo].Duplicates
where Cases = 'CaseVI'
Union 
select 
count(*) as Count,
concat(left(count(*)/cast(@countTotal*1.0 as numeric(19,2)) *100,4),'%') as 'Percentage',
'CaseVII' as Cases
from [dbo].Duplicates
where Cases = 'CaseVII'
Union 
select 
count(*) as Count,
concat(left(count(*)/cast(@countTotal*1.0 as numeric(19,2)) *100,4),'%') as 'Percentage',
'CaseVIII' as Cases
from [dbo].Duplicates
where Cases = 'CaseVIII'
Union 
select 
count(*) as Count,
concat(left(count(*)/cast(@countTotal*1.0 as numeric(19,2)) *100,4),'%') as 'Percentage',
'CaseIX' as Cases
from [dbo].Duplicates
where Cases = 'CaseIX'
Union 
select 
count(*) as Count,
concat(left(count(*)/cast(@countTotal*1.0 as numeric(19,2)) *100,4),'%') as 'Percentage',
'CaseX' as Cases
from [dbo].Duplicates
where Cases = 'CaseX'
Union 
select 
count(*) as Count,
concat(left(count(*)/cast(@countTotal*1.0 as numeric(19,2)) *100,4),'%') as 'Percentage',
'CaseXI' as Cases
from [dbo].Duplicates
where Cases = 'CaseXI'

alter table [dbo].Duplicates add Results varchar(200);
go
/* Strong Evidence of Duplication based on Case I */
update a 
set Results = 'Strong'
from [dbo].Duplicates a 
where Cases = 'CaseI'
and Results is null

--select * from [dbo].Duplicates where Results = 'Strong' order by 2
drop table if exists #Combine_CaseII_CaseVIII

/* Combining CaseII & CaseVIII as it shows the strong evidence of duplication */
select RecordID  
into #Combine_CaseII_CaseVIII
from [dbo].Duplicates
where Cases in ('CaseII','CaseVIII')
and Results is null
group by RecordID
having count(*)>1

update a 
set a.Results = 'Strong'
from [dbo].Duplicates a 
join #Combine_CaseII_CaseVIII b 
on a.RecordID = b.RecordID

drop table if exists #Combine_CaseVI_CaseVIII
/* Combining CaseVI & CaseVIII as it shows the strong evidence of duplication */
select RecordID  
into #Combine_CaseVI_CaseVIII
from [dbo].Duplicates
where Cases in ('CaseVI','CaseVIII')
and  Results is null
group by RecordID
having count(*)>1

update a 
set a.Results = 'Strong'
from [dbo].Duplicates a 
join #Combine_CaseVI_CaseVIII b 
on a.RecordID = b.RecordID

update a 
set a.Results = 'Strong'
from [dbo].Duplicates a 
where Cases = 'CaseVII'
and Results is null

/* Combining CaseVI & CaseII as it shows the strong evidence of duplication */
drop table if exists #Combine_CaseVI_CaseII
go
select RecordID  
into #Combine_CaseVI_CaseII
from [dbo].Duplicates
where Cases in ('CaseVI','CaseII')
and Results is null
group by RecordID
having count(*)>1

update a 
set a.Results = 'Strong'
from [dbo].Duplicates a 
join #Combine_CaseVI_CaseII b 
on a.RecordID = b.RecordID

/* Combining CaseVI & CaseV & CaseVIII as it shows the strong evidence of duplication */
drop table if exists #Combine_CaseVI_CaseV_CaseVIII
go 
select RecordID  
into #Combine_CaseVI_CaseV_CaseVIII
from [dbo].Duplicates
where Cases in ('CaseVI','CaseV','CaseVIII')
and Results is null
group by RecordID
having count(*)>1
go
update a 
set a.Results = 'Strong'
from [dbo].Duplicates a 
join #Combine_CaseVI_CaseV_CaseVIII b 
on a.RecordID = b.RecordID
go
update a 
set a.Results = 'Strong'
from [dbo].Duplicates a
where Cases = 'CaseIX'
and results is null
and Email_Domain not in ('gmail.com','yahoo.com','hotmail.com')

update a 
set a.Results = 'Strong'
from [dbo].Duplicates a
where Cases = 'CaseX'
and results is null
and domain not in ('gmail','hotmail','yahoo')

update a 
set a.Results = 'Strong'
from [dbo].Duplicates a
where Cases = 'CaseXI'
and results is null

/*
select * from [dbo].Duplicates
where Results is null order by 2
*/