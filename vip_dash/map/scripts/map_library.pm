package map_library;


use POSIX qw/strftime/;
use Shell;
use DBI;

#use File::Stat::Ls;
#use File::DirList;


sub file_exists()	{
my($filename)= @_;
	if(-e $filename)	{
		return 1;
	}
	else	{
		return 0;
	}
}

sub get_file_content()  {
my ($filename) = @_;

	#print "-----$filename\n";
	if(&file_exists($filename))	{
		open(PAGE,$filename) || die "File can't open: $filename";
		@File = <PAGE>;
		close(PAGE);
		return(@File);
	}
	else	{
		print "File not exists";
	}
}

sub read_confs()     {
my(%conf) = @_;
        @File = &get_file_content($conf{'ConfFile'});
	#print "@File";
        foreach my $line (@File)        {
                chomp($line);
                $line =~ s/#.*//g;
                $line =~ s/^ //g;
                $line =~ s/\t//g;
                if($line !~ // && $line =~ /:/) {
                    ($key, $value) = split(":",$line);
		    $key =~ s/\s//g;
                    $value =~ s/"//g;
                    $conf{$key} = $value;
                    print "$key-->$props{$key}\n";
                }
        }
	return(%conf);
}

sub get_nco_sql_result()	{
my($OMNI_SQL_PATH, $OMNI_USER, $OMNI_PASSWORD, $OMNI_OS, $OMNI_SQL_CMD) = @_;

#####################################################
# Don't tab, add spaces and newlines for the below
# nco_sql lines.
#####################################################

my $obj_serv_query = qq($OMNI_SQL_PATH -user $OMNI_USER -p $OMNI_PASSWORD -server $OMNI_OS -nosecure <<EOF

$OMNI_SQL_CMD

go

EOF);

	@result = `$obj_serv_query`;
	print $obj_serv_query;
	print "SQL Result ---->@result";
	return(@result);
}

sub parse_omni_results()	{
my (@alarm_rows) = @_;
	%Hash_Alarm = undef;
	$alarms_count = scalar(@alarm_rows);
	for(my $i = 34; $i<($alarms_count); $i = $i+17) {
        	
		print "PreVal(Start $i) -> $alarm_rows[$i],$alarm_rows[$i+1],$alarm_rows[$i+2],$alarm_rows[$i+3],$alarm_rows[$i+4],$alarm_rows[$i+5],$alarm_rows[$i+6],$alarm_rows[$i+7],$alarm_rows[$i+8],$alarm_rows[$i+9],$alarm_rows[$i+10],$alarm_rows[$i+11],$alarm_rows[$i+12],$alarm_rows[$i+13],$alarm_rows[$i+14],$alarm_rows[$i+15],$alarm_rows[$i+16]\n";

		for(my $j = 0; $j<17; $j = $j+1) {
			#print "PreParse($alarm_rows[$i+$j])\n";
			chomp($alarm_rows[$i+$j]);
			#$alarm_rows[$i+$j] =~ s/^\s+|\s+$//g;
			$alarm_rows[$i+$j] =~ s/\s*(\S+)\s*.*/$1/g;
			chomp($alarm_rows[$i+$j]);
			$alarm_rows[$i+$j] =~ s/\0+$//
			#print "PostParse($alarm_rows[$i+$j])\n";
		}

		#print "PostVal(Start $i) -> $alarm_rows[$i],$alarm_rows[$i+1],$alarm_rows[$i+2],$alarm_rows[$i+3],$alarm_rows[$i+4],$alarm_rows[$i+5],$alarm_rows[$i+6],$alarm_rows[$i+7],$alarm_rows[$i+8],$alarm_rows[$i+9],$alarm_rows[$i+10],$alarm_rows[$i+11],$alarm_rows[$i+12],$alarm_rows[$i+13],$alarm_rows[$i+14],$alarm_rows[$i+15],$alarm_rows[$i+16]\n";

	        $key = $alarm_rows[$i+2];
        	$Hash_Alarm{$key} = "$alarm_rows[$i+5],$alarm_rows[$i+6],$alarm_rows[$i+7],$alarm_rows[$i+8],$alarm_rows[$i+9],$alarm_rows[$i+14],$alarm_rows[$i+15],$alarm_rows[$i+16]";
	}
	delete($Hash_Alarm{''});
	return(%Hash_Alarm);
}


sub ConnectOracleDB()	{
my($ORA_HOST, $ORA_SID, $ORA_USER, $ORA_PASSWORD) = @_;

 
	# Get a database handle by connecting to the database
	$dbh = DBI->connect("dbi:Oracle:host=$ORA_HOST;sid=$ORA_SID", "$ORA_USER","$ORA_PASSWORD", {RaiseError => 1, AutoCommit => 1}) or die "Can't connect to database: $DBI::errstr\n";

	return($dbh);
}

sub QueryOracleDB()	{
my($dbh, $ORA_SQL_CMD) = @_;

	# Instead you could do $dbh->do($sql) or execute
	$sth = $dbh->prepare($ORA_SQL_CMD) or die "Can't prepare statement: $dbh->errstr\n";
	$sth->execute() or die "Can't execute statement: $sth->errstr\n";


	my %HashDB = undef;

	
	# Convert Array
	while (@rows = $sth->fetchrow_array()) {
		$HashDB{$rows[0]} = "$rows[1]";
		print "QueryOracleDB() --> $rows[0], rows[1]";
	}
	delete($HashDB{''});

	$sth->finish();
	$dbh->disconnect();
	return(%HashDB);
}

sub CreateNACopperXml() {
        
	my($dbh, $ORA_SQL_CMD) = @_;
        
        # Instead you could do $dbh->do($sql) or execute
        $sth = $dbh->prepare($ORA_SQL_CMD) or die "Can't prepare statement: $dbh->errstr\n";
        $sth->execute() or die "Can't execute statement: $sth->errstr\n";

        print "\nCreating NA-Copper XML\n";

	my $find = "&";
	my $replace = "&amp;";

        my $XmlString = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><data>";

        # Convert Array to XML String Row-by-Row
        while (@rows = $sth->fetchrow_array()) {
                
		print "QueryOracleDB() --> $rows[0], rows[1]";
		$XmlString .= "<row>";
		$XmlString .= "<kpi_date>$rows[0]</kpi_date>";
		$rows[1] =~ s/$find/$replace/g;
		$XmlString .= "<customername>$rows[1]</customername>";
		$XmlString .= "<circuitname>$rows[2]</circuitname>";
		$XmlString .= "<dsl_status>$rows[3]</dsl_status>";
		$XmlString .= "<servstability>$rows[4]</servstability>";
		$XmlString .= "<subsid>$rows[5]</subsid>";
		$XmlString .= "<line_id>$rows[6]</line_id>";
		$XmlString .= "<eddist>$rows[7]</eddist>";
		$XmlString .= "<xdslprofile>$rows[8]</xdslprofile>";
		$XmlString .= "<nmargin_ds>$rows[9]</nmargin_ds>";
		$XmlString .= "<nmargin_us>$rows[10]</nmargin_us>";
		$XmlString .= "<actspeed_ds>$rows[11]</actspeed_ds>";
		$XmlString .= "<actspeed_us>$rows[12]</actspeed_us>";
		$XmlString .= "<bitrate_ds>$rows[13]</bitrate_ds>";
		$XmlString .= "<bitrate_us>$rows[14]</bitrate_us>";
		$XmlString .= "<atten_ds>$rows[15]</atten_ds>";
		$XmlString .= "<atten_us>$rows[16]</atten_us>";
		$XmlString .= "<otraffic_ds>$rows[17]</otraffic_ds>";
		$XmlString .= "<otraffic_us>$rows[18]</otraffic_us>";
		$XmlString .= "<lastchgstatus>$rows[19]</lastchgstatus>";
		$XmlString .= "<hajj>$rows[20]</hajj>";
		$XmlString .= "<vip>$rows[21]</vip>";
		$XmlString .= "<hajjvipstatus>$rows[22]</hajjvipstatus>";
		$XmlString .= "</row>";
        }

        $sth->finish();
        $dbh->disconnect();

	$XmlString .= "</data>";

        return($XmlString);
}


sub CreateNAFiberXml() {

        my($dbh, $ORA_SQL_CMD) = @_;

        # Instead you could do $dbh->do($sql) or execute
        $sth = $dbh->prepare($ORA_SQL_CMD) or die "Can't prepare statement: $dbh->errstr\n";
        $sth->execute() or die "Can't execute statement: $sth->errstr\n";

        print "\nCreating NA-Fiber XML\n";

	my $find = "&";
	my $replace = "&amp;";

        my $XmlString = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><data>";

        # Convert Array to XML String Row-by-Row
        while (@rows = $sth->fetchrow_array()) {

                print "QueryOracleDB() --> $rows[0], rows[1]";
		$XmlString .= "<row>";
                $XmlString .= "<kpi_date>$rows[0]</kpi_date>";
                $rows[1] =~ s/$find/$replace/g;
		$XmlString .= "<customer>$rows[1]</customer>";
                $XmlString .= "<circuit>$rows[2]</circuit>";
                $XmlString .= "<ontslid>$rows[3]</ontslid>";
                $XmlString .= "<ontaddress>$rows[4]</ontaddress>";
		$XmlString .= "<ontserial>$rows[5]</ontserial>";
		$XmlString .= "<edistolt>$rows[6]</edistolt>";
		$XmlString .= "<linkstatus>$rows[7]</linkstatus>";
		$XmlString .= "<linkquality>$rows[8]</linkquality>";
		$XmlString .= "<ontstatus>$rows[9]</ontstatus>";
		$XmlString .= "<rxsignallvls>$rows[10]</rxsignallvls>";
		$XmlString .= "<rxsignalont>$rows[11]</rxsignalont>";
		$XmlString .= "<rxsignalolt>$rows[12]</rxsignalolt>";
		$XmlString .= "<hajj>$rows[13]</hajj>";
                $XmlString .= "<vip>$rows[14]</vip>";
                $XmlString .= "<hajjvipstatus>$rows[15]</hajjvipstatus>";
		$XmlString .= "</row>";
        }

        $sth->finish();
        $dbh->disconnect();

        $XmlString .= "</data>";

        return($XmlString);
}


sub CreateTTAllOpenXml() {

        my($dbh, $ORA_SQL_CMD) = @_;

        # Instead you could do $dbh->do($sql) or execute
        $sth = $dbh->prepare($ORA_SQL_CMD) or die "Can't prepare statement: $dbh->errstr\n";
        $sth->execute() or die "Can't execute statement: $sth->errstr\n";

        print "\nCreating All Open TTs XML\n";

	my $find = "&";
	my $replace = "&amp;";

        my $XmlString = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><data>";

        # Convert Array to XML String Row-by-Row
        while (@rows = $sth->fetchrow_array()) {

                print "QueryOracleDB() --> $rows[0], rows[1]";
		$XmlString .= "<row>";
                $XmlString .= "<ttid>$rows[0]</ttid>";
		$rows[1] =~ s/$find/$replace/g;
                $XmlString .= "<customer>$rows[1]</customer>";
                $XmlString .= "<vpnlinkname>$rows[2]</vpnlinkname>";
		$XmlString .= "<severity>$rows[3]</severity>";
		$XmlString .= "<rttsseverity>$rows[12]</rttsseverity>";
		$XmlString .= "<status>$rows[4]</status>";
		$XmlString .= "<tttarget>$rows[5]</tttarget>";
		$rows[6] =~ s/$find/$replace/g;
		$XmlString .= "<currentgrp>$rows[6]</currentgrp>";
		$XmlString .= "<ttcreatedate>$rows[7]</ttcreatedate>";
                $XmlString .= "<ttclosedate>$rows[8]</ttclosedate>";
		$XmlString .= "<hajj>$rows[9]</hajj>";
                $XmlString .= "<vip>$rows[10]</vip>";
                $XmlString .= "<hajjvipstatus>$rows[11]</hajjvipstatus>";
		$XmlString .= "</row>";
        }

        $sth->finish();
        $dbh->disconnect();

        $XmlString .= "</data>";

        return($XmlString);
}


sub CreateTTClosedWeekXml() {

        my($dbh, $ORA_SQL_CMD) = @_;

        # Instead you could do $dbh->do($sql) or execute
        $sth = $dbh->prepare($ORA_SQL_CMD) or die "Can't prepare statement: $dbh->errstr\n";
        $sth->execute() or die "Can't execute statement: $sth->errstr\n";

        print "\nCreating TTs Closed XML\n";

        my $XmlString = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><data>";

        # Convert Array to XML String Row-by-Row
        while (@rows = $sth->fetchrow_array()) {

                print "QueryOracleDB() --> $rows[0], rows[1]";
		$XmlString .= "<row>";
		$XmlString .= "<row>";
                $XmlString .= "<ttid>$rows[0]</ttid>";
                $XmlString .= "<customer>$rows[1]</customer>";
                $XmlString .= "<vpnlinkname>$rows[2]</vpnlinkname>";
                $XmlString .= "<status>$rows[3]</status>";
                $XmlString .= "<severity>$rows[4]</severity>";
		$XmlString .= "<rttsseverity>$rows[12]</rttsseverity>";
                $XmlString .= "<tttarget>$rows[5]</tttarget>";
                $XmlString .= "<ownergrp>$rows[6]</ownergrp>";
                $XmlString .= "<ttcreatedate>$rows[7]</ttcreatedate>";
                $XmlString .= "<ttclosedate>$rows[8]</ttclosedate>";
		$XmlString .= "<hajj>$rows[9]</hajj>";
                $XmlString .= "<vip>$rows[10]</vip>";
                $XmlString .= "<hajjvipstatus>$rows[11]</hajjvipstatus>";
		$XmlString .= "</row>";
        }

        $sth->finish();
        $dbh->disconnect();

        $XmlString .= "</data>";

        return($XmlString);
}


sub CreateTTEscalatedXml() {

        my($dbh, $ORA_SQL_CMD) = @_;

        # Instead you could do $dbh->do($sql) or execute
        $sth = $dbh->prepare($ORA_SQL_CMD) or die "Can't prepare statement: $dbh->errstr\n";
        $sth->execute() or die "Can't execute statement: $sth->errstr\n";

        print "\nCreating Escalated TTs XML\n";

        my $XmlString = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><data>";

        # Convert Array to XML String Row-by-Row
        while (@rows = $sth->fetchrow_array()) {

                print "QueryOracleDB() --> $rows[0], rows[1]";
		$XmlString .= "<row>";
                $XmlString .= "<ttid>$rows[0]</ttid>";
                $XmlString .= "<customer>$rows[1]</customer>";
                $XmlString .= "<vpnlinkname>$rows[2]</vpnlinkname>";
                $XmlString .= "<slapackage>$rows[3]</slapackage>";
                $XmlString .= "<status>$rows[4]</status>";
                $XmlString .= "<escalationlevel>$rows[5]</escalationlevel>";
                $XmlString .= "<escalationtime>$rows[6]</escalationtime>";
                $XmlString .= "<ttcreatedate>$rows[7]</ttcreatedate>";
                $XmlString .= "<ttseverity>$rows[8]</ttseverity>";
                $XmlString .= "<ttresolutiontarget>$rows[9]</ttresolutiontarget>";
		$XmlString .= "<ttage>$rows[10]</ttage>";
		$XmlString .= "<hajj>$rows[11]</hajj>";
                $XmlString .= "<vip>$rows[12]</vip>";
                $XmlString .= "<hajjvipstatus>$rows[13]</hajjvipstatus>";
		$XmlString .= "</row>";
        }

        $sth->finish();
        $dbh->disconnect();

        $XmlString .= "</data>";

        return($XmlString);
}


sub CreateUtilizationXml() {

        my($dbh, $ORA_SQL_CMD) = @_;

        # Instead you could do $dbh->do($sql) or execute
        $sth = $dbh->prepare($ORA_SQL_CMD) or die "Can't prepare statement: $dbh->errstr\n";
        $sth->execute() or die "Can't execute statement: $sth->errstr\n";

        print "\nCreating TTs Under-Monitoring XML\n";

	my $find = "&";
	my $replace = "&amp;";

        my $XmlString = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><data>";

        # Convert Array to XML String Row-by-Row
        while (@rows = $sth->fetchrow_array()) {

                print "QueryOracleDB() --> $rows[0], rows[1]";

		$XmlString .= "<row>";
                $XmlString .= "<kpi_date>$rows[0]</kpi_date>";
                $rows[1] =~ s/$find/$replace/g;
		$XmlString .= "<customer>$rows[1]</customer>";
                $XmlString .= "<vpnlinkname>$rows[2]</vpnlinkname>";
                $XmlString .= "<bandwidth>$rows[3]</bandwidth>";
                $XmlString .= "<util>$rows[4]</util>";
		$XmlString .= "<hajj>$rows[5]</hajj>";
                $XmlString .= "<vip>$rows[6]</vip>";
                $XmlString .= "<hajjvipstatus>$rows[7]</hajjvipstatus>";
		$XmlString .= "</row>";
        }

        $sth->finish();
        $dbh->disconnect();

        $XmlString .= "</data>";

        return($XmlString);
}

sub QueryInventoryHash() {

        my($dbh, $ORA_SQL_CMD) = @_;

        print "\nCreating Inventory Hash Map\n";

        # Instead you could do $dbh->do($sql) or execute
        $sth = $dbh->prepare($ORA_SQL_CMD) or die "Can't prepare statement: $dbh->errstr\n";
        $sth->execute() or die "Can't execute statement: $sth->errstr\n";

        my %HashDB = undef;

        # Convert Array
        while (@rows = $sth->fetchrow_array()) {
                $HashDB{$rows[2]} = "$rows[0],$rows[1],$rows[2],$rows[3],$rows[4],$rows[5],$rows[6]";
                print "QueryInventoryHash() --> $rows[0], $rows[1], $rows[2], $rows[3], $rows[4], $rows[5], $rows[6]\n";
        }
        delete($HashDB{''});

        $sth->finish();
        $dbh->disconnect();
        return(%HashDB);

}

sub QueryTechStatusHash() {

        my($dbh, $ORA_SQL_CMD) = @_;

        print "\nCreating UPE/NA Technology Status Hash Map\n";

        # Instead you could do $dbh->do($sql) or execute
        $sth = $dbh->prepare($ORA_SQL_CMD) or die "Can't prepare statement: $dbh->errstr\n";
        $sth->execute() or die "Can't execute statement: $sth->errstr\n";

        my %HashDB = undef;

        # Convert Array
        while (@rows = $sth->fetchrow_array()) {
                $HashDB{$rows[0]} = "$rows[1],$rows[2]";
                print "QueryTechStatusHash($rows[0]) --> $rows[1], $rows[2]\n";
        }
        delete($HashDB{''});

        $sth->finish();
        $dbh->disconnect();
        return(%HashDB);

}

sub CreateUpeAlarmsXml() {

        my($dbh, $ORA_SQL_CMD) = @_;

        # Instead you could do $dbh->do($sql) or execute
        $sth = $dbh->prepare($ORA_SQL_CMD) or die "Can't prepare statement: $dbh->errstr\n";
        $sth->execute() or die "Can't execute statement: $sth->errstr\n";

        print "\nCreating UPE Alarms XML\n";

        my $XmlString = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><data>";

        # Convert Array to XML String Row-by-Row
        while (@rows = $sth->fetchrow_array()) {

                print "QueryOracleDB() --> $rows[0], rows[1]";

                $XmlString .= "<row>";
                $XmlString .= "<kpi_date>$rows[0]</kpi_date>";
                $XmlString .= "<customer>$rows[1]</customer>";
                $XmlString .= "<vpnlinkname>$rows[2]</vpnlinkname>";
                $XmlString .= "<status>$rows[5]</status>";
                $XmlString .= "<slotport>$rows[3]/$rows[4]</slotport>";
                $XmlString .= "<vip>$rows[6]</vip>";
                $XmlString .= "</row>";
        }

        $sth->finish();
        $dbh->disconnect();

        $XmlString .= "</data>";

        return($XmlString);
}

sub CreateMissingDataXml() {

        my($dbh, $ORA_SQL_CMD, $FILE_OT_MISSING) = @_;

        # Instead you could do $dbh->do($sql) or execute
        $sth = $dbh->prepare($ORA_SQL_CMD) or die "Can't prepare statement: $dbh->errstr\n";
        $sth->execute() or die "Can't execute statement: $sth->errstr\n";

	open FILE_OT, ">", "$FILE_OT_MISSING\.0" or die $!;

	print FILE_OT "Customer,Circuit Name,Latitude,Longitude,UPE Node,UPE Site,UPE Slot,UPE Port\n";

        print "\nCreating Missing Data XML\n";

        my $XmlString = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><data>";

        # Convert Array to XML String Row-by-Row
        while (@rows = $sth->fetchrow_array()) {

                print "QueryOracleDB() --> $rows[0], rows[1]";

                $XmlString .= "<row>";
		$customer = $rows[0];
		$customer =~ s/"&"/"and"/g;
		print "CUSTOMER --> $customer\n";
                $XmlString .= "<customer>$customer</customer>";
                $XmlString .= "<vpnlinkname>$rows[1]</vpnlinkname>";
		$XmlString .= "<latitude>$rows[2]</latitude>";
		$XmlString .= "<longitude>$rows[3]</longitude>";
		$XmlString .= "<upenode>$rows[4]</upenode>";
		$XmlString .= "<upesite>$rows[5]</upesite>";
		$XmlString .= "<upeslot>$rows[6]</upeslot>";
		$XmlString .= "<upeport>$rows[7]</upeport>";
                $XmlString .= "</row>";

		print FILE_OT "$rows[0],$rows[1],$rows[2],$rows[3],$rows[4],$rows[5],$rows[6],$rows[7]\n";
        }

        $sth->finish();
        $dbh->disconnect();

        $XmlString .= "</data>";

	`mv -f "$FILE_OT_MISSING\.0" "$FILE_OT_MISSING"`;

        return($XmlString);
}

1;
