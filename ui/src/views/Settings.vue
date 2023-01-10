<template>
  <div>
    <h1>{{$t('settings.title')}}</h1>

    <!-- error message -->
    <div v-if="errorMessage" class="alert alert-danger alert-dismissable">
      <span class="pficon pficon-error-circle-o"></span>
      {{ errorMessage }}.
    </div>

    <!-- DNS blacklist enabled warning -->
    <div v-if="ftlEnabled" class="alert alert-warning alert-dismissable">
      <span class="pficon pficon-warning-triangle-o"></span>
      <strong>{{$t('warning')}}: </strong>
      <span>{{$t('dashboard.dns_blacklist_enabled')}}.
        <a href="/nethserver#/applications/nethserver-blacklist" target="_blank">
          {{$t('dashboard.configure_threat_shield')}}
        </a>
      </span>
    </div>

    <div v-if="!uiLoaded" class="spinner spinner-lg"></div>
    <div v-if="uiLoaded">
      <!-- banner -->
      <div v-if="!ftlEnabled && showBanner" class="alert alert-info">
        <span class="pficon pficon-info"></span>
        <p>
          {{$t('settings.dns_configuration')}}.
        </p>
        <p>
          {{$t('settings.before_using_flashstart')}} <a v-bind:href="portalUrl" target="_blank">{{ portalUrl }}</a>.
        </p>
      </div>

      <form class="form-horizontal" v-on:submit.prevent="btSaveClick">
        <!-- enable flashstart -->
        <div class="form-group">
          <label
            class="col-sm-2 control-label"
            for="textInput-modal-markup"
          >{{$t('settings.enable_flashstart_filter')}}</label>
          <div class="col-sm-3">
            <toggle-button
              class="min-toggle"
              :width="40"
              :height="20"
              :color="{checked: '#0088ce', unchecked: '#bbbbbb'}"
              :value="enableFlashstart"
              :sync="true"
              @change="toggleEnableFlashstart()"
            />
          </div>
        </div>
        <div v-if="enableFlashstart">
          <h3>{{$t('settings.flashstart_auth')}}</h3>
          <!-- username -->
          <div class="form-group" :class="{ 'has-error': showErrorUsername }">
            <label
              class="col-sm-2 control-label"
              for="textInput-modal-markup"
            >{{$t('settings.username_email')}}</label>
            <div class="col-sm-3">
              <input type="input" class="form-control" v-model="flashstartConfig.Username">
              <span class="help-block" v-if="showErrorUsername">
                {{ errorUsername === 'bad_login' ? $t('settings.username_validation_bad_login') : $t('settings.username_validation') }}
              </span>
            </div>
          </div>
          <!-- password -->
          <div class="form-group" :class="{ 'has-error': showErrorPassword }">
            <label
              class="col-sm-2 control-label"
              for="textInput-modal-markup"
            >{{$t('settings.password')}}</label>
            <div class="col-sm-3">
              <input
                :type="passwordVisible ? 'text' : 'password'"
                class="form-control"
                v-model="flashstartConfig.Password"
              >
              <span class="help-block" v-if="showErrorPassword">
                {{ errorPassword === 'bad_login' ? $t('settings.password_validation_bad_login') : $t('settings.password_validation') }}
              </span>
            </div>
            <!-- password visibility -->
            <div class="col-sm-1 adjust-index">
              <button
                tabindex="-1"
                type="button"
                class="btn btn-primary"
                @click="togglePasswordVisibility()"
              >
                <span :class="[!passwordVisible ? 'fa fa-eye' : 'fa fa-eye-slash']"></span>
              </button>
            </div>
          </div>
          <div class="divider"></div>

          <!-- network checkboxes -->
          <h3>{{$t('settings.networks_to_filter')}}</h3>
          <div
            class="form-group"
            v-for="(role, index) in networkRoles"
            v-bind:key="index"
          >
            <label class="col-sm-2 control-label">
              {{$t('settings.' + role + '_network_description')}}
            </label>
            <div class="col-sm-3">
              <input
                v-model="rolesFilter[role]"
                type="checkbox"
                class="form-control"
              >
            </div>
          </div>
          <div class="divider"></div>

          <!-- bypass source ips -->
          <h3>{{$t('settings.bypass')}}</h3>
          <div class="form-group" :class="{ 'has-error': showErrorBypass }">
            <label
              class="col-sm-2 control-label"
              for="textInput-modal-markup"
            >
              {{$t('settings.bypass_source_ips')}}
            </label>
            <div class="col-sm-3">
              <textarea
                class="form-control"
                type="checkbox"
                placeholder=""
                v-model= "bypassText"
              ></textarea>
              <span class="help-block" v-if="showErrorBypass">
                {{$t('settings.bypass_validation')}}
              </span>
            </div>
          </div>
        </div>
        <!-- save button -->
        <div class="form-group">
          <label class="col-sm-2 control-label">
            <div
              v-if="saveLoader"
              class="spinner spinner-sm form-spinner-loader adjust-top-loader"
            ></div>
          </label>
          <div class="col-sm-3">
            <button 
              class="btn btn-primary" 
              type="submit"
              :disabled="saveLoader"
            >
              {{$t('save')}}
            </button>
          </div>
        </div>
      </form>
    </div>
  </div>
</template>

<script>
  export default {
    name: "Settings",
    components: {
    },
    props: {
    },
    mounted() {
      this.getFlashstartConfig()
      this.getFtlEnabled();
    },
    data() {
      return {
        uiLoaded: true,
        errorMessage: null,
        enableFlashstart: false,
        showErrorUsername: false,
        showErrorPassword: false,
        showErrorBypass: false,
        errorUsername: '',
        errorPassword: '',
        passwordVisible: false,
        flashstartConfig: null,
        rolesFilter: [],
        networkRoles: [],
        bypassText: '',
        showBanner: false,
        saveLoader: false,
        ftlEnabled: false
      };
    },
    methods: {
      getFlashstartConfig() {
        this.uiLoaded = false;
        var ctx = this;
        nethserver.exec(
          ["nethserver-flashstart/read"],
          { "config": "flashstart" },
          null,
          function(success) {
            var output = JSON.parse(success);
            ctx.getFlashstartConfigSuccess(output)
          },
          function(error) {
            ctx.showErrorMessage(ctx.$i18n.t("settings.error_reading_flashstart_configuration"), error)
          }
        );
      },
      getFlashstartConfigSuccess(flashstartConfigOutput) {
        this.flashstartConfig = flashstartConfigOutput.configuration.props
        this.enableFlashstart = this.flashstartConfig.status === 'enabled'
        this.portalUrl = this.flashstartConfig.PortalUrl

        if (!this.flashstartConfig.Username || !this.flashstartConfig.Password) {
          this.showBanner = true
        } else {
          this.showBanner = false
        }

        var roles = this.flashstartConfig.Roles.split(",")
        for (var role of roles) {
          if (role) { // skip empty string
            this.rolesFilter[role] = true
          }
        }

        this.bypassText = this.flashstartConfig.Bypass.replace(/,/g, "\n")
        var ctx = this;
        nethserver.exec(
          ["nethserver-flashstart/read"],
          { "config": "networkRoles" },
          null,
          function(success) {
            var output = JSON.parse(success);
            ctx.getNetworkRolesSuccess(output)
          },
          function(error) {
            ctx.showErrorMessage(ctx.$i18n.t("settings.error_reading_network_roles_configuration"), error)
          }
        );
      },
      getNetworkRolesSuccess(networkRolesOutput) {
        this.networkRoles = networkRolesOutput.configuration.networkRoles
        this.uiLoaded = true
      },
      closeErrorMessage() {
        this.errorMessage = null
      },
      showErrorMessage(errorMessage, error) {
        this.uiLoaded = true;
        console.error(errorMessage, error) /* eslint-disable-line no-console */
        this.errorMessage = errorMessage
      },
      toggleEnableFlashstart() {
        this.enableFlashstart = !this.enableFlashstart;
      },
      togglePasswordVisibility() {
        this.passwordVisible = !this.passwordVisible;
      },
      btSaveClick() {
        this.saveLoader = true
        this.showErrorUsername = false
        this.showErrorPassword = false
        this.showErrorBypass = false
        this.errorMessage = null
        
        var rolesFilter = []
        for (var role in this.rolesFilter) {
          var selected = this.rolesFilter[role]
          if (selected == true) {
            rolesFilter.push(role)
          }
        }

        var validateObj = {
          "enableFlashstart": this.enableFlashstart ? "enabled" : "disabled",
          "username": this.flashstartConfig.Username,
          "password": this.flashstartConfig.Password,
          "rolesFilter": rolesFilter,
          "bypass": this.bypassText.trim().split("\n")
        }
        var ctx = this;
        nethserver.exec(
          ["nethserver-flashstart/validate"],
          validateObj,
          null,
          function(success) {
            ctx.validationSuccess(validateObj)
          },
          function(error, data) {
            ctx.validationError(error, data)
            ctx.saveLoader = false
          }
        );
      },
      validationSuccess(validateObj) {
        this.uiLoaded = false
        this.saveLoader = false
        nethserver.notifications.success = this.$i18n.t("settings.configuration_update_successful");
        nethserver.notifications.error = this.$i18n.t("settings.configuration_update_failed");
        var ctx = this
        nethserver.exec(
          ["nethserver-flashstart/update"],
          validateObj,
          function(stream) {
            console.info("flashstart-configuration-update", stream); /* eslint-disable-line no-console */
          },
          function(success) {
            ctx.getFlashstartConfig()
          },
          function(error) {
            console.error(error)  /* eslint-disable-line no-console */
            ctx.saveLoader = false
            ctx.uiLoaded = true
          }
        );
      },
      validationError(error, data) {
        var errorData = JSON.parse(data);

        for (var e in errorData.attributes) {
          var attr = errorData.attributes[e]
          var param = attr.parameter;

          if (param === 'username') {
            this.showErrorUsername = true;
            this.errorUsername = attr.error;
          } else if (param === 'password') {
            this.showErrorPassword = true;
            this.errorPassword = attr.error;
          } else if (param === 'bypass') {
            this.showErrorBypass = true;
          }
        }
      },
      getFtlEnabled() {
        // Check if DNS blacklist is enabled
        var ctx = this;
        nethserver.exec(
          ["nethserver-flashstart/read"],
          { "config": "ftl" },
          null,
          function(success) {
            var output = JSON.parse(success);

            if (output.configuration.props) {
              const status = output.configuration.props.status === 'enabled';
              const roles = output.configuration.props.Roles;
              ctx.ftlEnabled = status && roles;
            } else {
              // DNS blacklist not installed
              ctx.ftlEnabled = false;
            }
          },
          function(error) {
            console.error(error);
            ctx.uiLoaded = true;
          }
        );
      }
    }
  }
</script>

<style>
.divider {
  border-bottom: 1px solid #d1d1d1;
}

textarea {
  min-height: 150px;
}

h1, h2, h3 {
  margin-bottom: 20px;
}
</style>
