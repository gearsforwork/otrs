# --
# Copyright (C) 2001-2016 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get selenium object
my $Selenium = $Kernel::OM->Get('Kernel::System::UnitTest::Selenium');

$Selenium->RunTest(
    sub {

        # get helper object
        my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

        # create test user and login
        my $TestUserLogin = $Helper->TestUserCreate(
            Groups => ['admin'],
        ) || die "Did not get test user";

        $Selenium->Login(
            Type     => 'Agent',
            User     => $TestUserLogin,
            Password => $TestUserLogin,
        );

        # get script alias
        my $ScriptAlias = $Kernel::OM->Get('Kernel::Config')->Get('ScriptAlias');

        # navigate to AdminSystemMaintenance screen
        $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=AdminSystemMaintenance");

        # check overview screen
        $Selenium->find_element( "table",             'css' );
        $Selenium->find_element( "table thead tr th", 'css' );
        $Selenium->find_element( "table tbody tr td", 'css' );

        # click "Schedule New System Maintenance"
        $Selenium->find_element("//a[contains(\@href, \'Subaction=SystemMaintenanceNew' )]")->VerifiedClick();

        # check Schedule New System Maintenance screen
        for my $ID (
            qw(StartDateDay StartDateMonth StartDateYear StartDateDayDatepickerIcon StartDateHour StartDateMinute
            StopDateDay StopDateMonth StopDateYear StopDateDayDatepickerIcon StopDateHour StopDateMinute
            Comment LoginMessage ShowLoginMessage NotifyMessage ValidID)
            )
        {
            my $Element = $Selenium->find_element( "#$ID", 'css' );
            $Element->is_enabled();
            $Element->is_displayed();
        }

        # check client side validation
        $Selenium->find_element( "#Comment", 'css' )->clear();
        $Selenium->find_element( "#Comment", 'css' )->VerifiedSubmit();
        $Self->Is(
            $Selenium->execute_script(
                "return \$('#Comment').hasClass('Error')"
            ),
            '1',
            'Client side validation correctly detected missing input value',
        );

        # get time object
        my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');

        # create error test SystemMaintenance scenario
        # get test end time - 1 hour of current time
        my ( $SecWrong, $MinWrong, $HourWrong, $DayWrong, $MonthWrong, $YearWrong, ) = $TimeObject->SystemTime2Date(
            SystemTime => $TimeObject->SystemTime() - 60 * 60,
        );

        my $SysMainComment = "sysmaintenance" . $Helper->GetRandomID();
        my $SysMainLogin   = "Selenium test SystemMaintance is progress, please log in later on";
        my $SysMainNotify  = "Currently Selenium SystemMaintenance test is active";

        $Selenium->find_element( "#Comment", 'css' )->send_keys($SysMainComment);

        $Selenium->find_element( "#StopDateDay option[value='" . int($DayWrong) . "']",     'css' )->click();
        $Selenium->find_element( "#StopDateMonth option[value='" . int($MonthWrong) . "']", 'css' )->click();
        $Selenium->execute_script(
            "\$('#StopDateYear').val('$YearWrong').trigger('redraw.InputField').trigger('change');"
        );
        $Selenium->find_element( "#StopDateHour option[value='" . int($HourWrong) . "']",  'css' )->click();
        $Selenium->find_element( "#StopDateMinute option[value='" . int($MinWrong) . "']", 'css' )->click();

        $Selenium->find_element( "#Comment", 'css' )->VerifiedSubmit();
        $Self->True(
            index( $Selenium->get_page_source(), "Start date shouldn\'t be defined after Stop date!" ) > -1,
            "Error message correctly displayed",
        );

        # get test start time + 1 hour of system time
        my ( $SecStart, $MinStart, $HourStart, $DayStart, $MonthStart, $YearStart, ) = $TimeObject->SystemTime2Date(
            SystemTime => $TimeObject->SystemTime() + 60 * 60,
        );

        # get test end time + 2 hour of system time
        my ( $SecEnd, $MinEnd, $HourEnd, $DayEnd, $MonthEnd, $YearEnd ) = $TimeObject->SystemTime2Date(
            SystemTime => $TimeObject->SystemTime() + 2 * 60 * 60,
        );

        # create real test SystemMaintenance
        $Selenium->find_element( "#StartDateDay option[value='" . int($DayStart) . "']",     'css' )->click();
        $Selenium->find_element( "#StartDateMonth option[value='" . int($MonthStart) . "']", 'css' )->click();
        $Selenium->execute_script(
            "\$('#StartDateYear').val('$YearStart').trigger('redraw.InputField').trigger('change');"
        );
        $Selenium->find_element( "#StartDateHour option[value='" . int($HourStart) . "']",  'css' )->click();
        $Selenium->find_element( "#StartDateMinute option[value='" . int($MinStart) . "']", 'css' )->click();
        $Selenium->find_element( "#StopDateDay option[value='" . int($DayEnd) . "']",       'css' )->click();
        $Selenium->find_element( "#StopDateMonth option[value='" . int($MonthEnd) . "']",   'css' )->click();
        $Selenium->execute_script(
            "\$('#StopDateYear').val('$YearEnd').trigger('redraw.InputField').trigger('change');"
        );
        $Selenium->find_element( "#StopDateHour option[value='" . int($HourEnd) . "']",  'css' )->click();
        $Selenium->find_element( "#StopDateMinute option[value='" . int($MinEnd) . "']", 'css' )->click();
        $Selenium->find_element( "#LoginMessage",  'css' )->send_keys($SysMainLogin);
        $Selenium->find_element( "#NotifyMessage", 'css' )->send_keys($SysMainNotify);
        $Selenium->find_element( "#Comment",       'css' )->VerifiedSubmit();

        # return to overview AdminSystemMaintenance
        $Selenium->find_element("//a[contains(\@href, \'Action=AdminSystemMaintenance' )]")->VerifiedClick();

        # check for created test SystemMaintenance
        $Self->True(
            index( $Selenium->get_page_source(), $SysMainComment ) > -1,
            "$SysMainComment found on page",
        );

        # get DB object
        my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

        # get test SystemMaintenanceID
        my $SysMainCommentQuoted = $DBObject->Quote($SysMainComment);
        $DBObject->Prepare(
            SQL  => "SELECT id FROM system_maintenance WHERE comments = ?",
            Bind => [ \$SysMainCommentQuoted ]
        );
        my $SysMainID;
        while ( my @Row = $DBObject->FetchrowArray() ) {
            $SysMainID = $Row[0];
        }

        # go to new test SystemMaintenance and check values
        $Selenium->find_element(
            "//a[contains(\@href, \'Subaction=SystemMaintenanceEdit;SystemMaintenanceID=$SysMainID' )]"
        )->VerifiedClick();
        $Self->Is(
            $Selenium->find_element( '#Comment', 'css' )->get_value(),
            $SysMainComment,
            "#Comment stored value",
        );
        $Self->Is(
            $Selenium->find_element( '#LoginMessage', 'css' )->get_value(),
            $SysMainLogin,
            "#LoginMessage stored value",
        );
        $Self->Is(
            $Selenium->find_element( '#NotifyMessage', 'css' )->get_value(),
            $SysMainNotify,
            "#NotifyMessage stored value",
        );
        $Self->Is(
            $Selenium->find_element( '#ValidID', 'css' )->get_value(),
            1,
            "#ValidID stored value",
        );

        # edit test SystemMaintenance and set it to invalid
        $Selenium->find_element( "#LoginMessage",  'css' )->send_keys("-update");
        $Selenium->find_element( "#NotifyMessage", 'css' )->send_keys("-update");
        $Selenium->execute_script("\$('#ValidID').val('2').trigger('redraw.InputField').trigger('change');");
        $Selenium->find_element( "#Comment", 'css' )->VerifiedSubmit();

        $Selenium->find_element("//a[contains(\@href, \'Action=AdminSystemMaintenance' )]")->VerifiedClick();

        # check class of invalid SystemMaintenance in the overview table
        $Self->True(
            $Selenium->execute_script(
                "return \$('tr.Invalid td:contains($SysMainComment)').length"
            ),
            "There is a class 'Invalid' for test SystemMaintenance",
        );

        # check updated test SystemMaintenance values
        $Selenium->find_element(
            "//a[contains(\@href, \'Subaction=SystemMaintenanceEdit;SystemMaintenanceID=$SysMainID' )]"
        )->VerifiedClick();
        $Self->Is(
            $Selenium->find_element( '#LoginMessage', 'css' )->get_value(),
            "$SysMainLogin-update",
            "#LoginMessage updated value",
        );
        $Self->Is(
            $Selenium->find_element( '#NotifyMessage', 'css' )->get_value(),
            "$SysMainNotify-update",
            "#NotifyMessage updated value",
        );
        $Self->Is(
            $Selenium->find_element( '#ValidID', 'css' )->get_value(),
            2,
            "#ValidID updated value",
        );

        # delete test SystemMaintenance
        my $Success = $Kernel::OM->Get('Kernel::System::SystemMaintenance')->SystemMaintenanceDelete(
            ID     => $SysMainID,
            UserID => 1,
        );
        $Self->True(
            $Success,
            "Deleted - $SysMainComment",
        );

    }

);

1;
