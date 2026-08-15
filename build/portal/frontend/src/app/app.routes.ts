import { Routes } from '@angular/router';
import { AccountComponent } from './account/account.component';
import { LiveComponent } from './live/live.component';
import { AdminBlogComponent } from './admin-blog/admin-blog.component';
import { AdminFlightsComponent } from './admin-flights/admin-flights.component';
import { AdminDevicesComponent } from './admin-devices/admin-devices.component';
import { AdminLiveComponent } from './admin-live/admin-live.component';
import { AdminLinksComponent } from './admin-links/admin-links.component';
import { AdminFeedersComponent } from './admin-feeders/admin-feeders.component';
import { AdminUsersComponent } from './admin-users/admin-users.component';
import { BlogComponent } from './blog/blog.component';
import { AcarsComponent } from './acars/acars.component';
import { AdminAcarsComponent } from './admin-acars/admin-acars.component';
import { AdminSchedulerComponent } from './admin-scheduler/admin-scheduler.component';
import { AdminXAlertComponent } from './admin-x-alert/admin-x-alert.component';
import { FlightsComponent } from './flights/flights.component';
import { LoginComponent } from './login/login.component';
import { DevicesComponent } from './devices/devices.component';
import { AisComponent } from './ais/ais.component';
import { AdminAisComponent } from './admin-ais/admin-ais.component';
import { RegisterComponent } from './register/register.component';
import { adminGuard } from './shared/admin.guard';
import { authGuard } from './shared/auth.guard';

export const routes = [
    { path: '', component: LiveComponent },
    { path: 'account', component: AccountComponent, canActivate: [authGuard] },
    { path: 'acars', component: AcarsComponent },
    { path: 'acars/:page', component: AcarsComponent },
    {
        path: 'admin',
        canActivateChild: [adminGuard],
        children: [
            { path: '', redirectTo: 'live', pathMatch: 'full' },
            { path: 'acars', component: AdminAcarsComponent },
            { path: 'ais', component: AdminAisComponent },
            { path: 'blog', component: AdminBlogComponent },
            { path: 'flights', component: AdminFlightsComponent },
            { path: 'devices', component: AdminDevicesComponent },
            { path: 'live', component: AdminLiveComponent },
            { path: 'links', component: AdminLinksComponent },
            { path: 'feeders', component: AdminFeedersComponent },
            { path: 'scheduler', component: AdminSchedulerComponent },
            { path: 'x-alert', component: AdminXAlertComponent },
            { path: 'users', component: AdminUsersComponent },
            { path: '**', redirectTo: 'live' },
        ],
    },
    { path: 'blog', component: BlogComponent },
    { path: 'blog/:page', component: BlogComponent },
    { path: 'blog-post/:id', component: BlogComponent },
    { path: 'flight-history/adsb/:flight', component: FlightsComponent },
    { path: 'flight-history/uat/:flight',  component: FlightsComponent },
    { path: 'flights', component: FlightsComponent },
    { path: 'flights/:page', component: FlightsComponent },
    { path: 'login', component: LoginComponent },
    { path: 'devices', component: DevicesComponent },
    { path: 'ais', component: AisComponent },
    { path: 'register', component: RegisterComponent }
] satisfies Routes;
