require 'dwolla'

class DashboardController < ApplicationController

	# Generally, it is best to handle errors in every function for every case,
	# however, given that this is a toy application and we will only throw API errors,
	# it is ok to do this.
	rescue_from Dwolla::DwollaError, :with => :rescue_dwolla_errors

	def rescue_dwolla_errors(exception)
		reset_session if exception.message == "Expired access token." or exception.message == "Invalid access token."

		if exception.message != "Expired access token." or exception.message != "Invalid access token."
			flash[:error] = "Uh oh! A Dwolla API error was encountered: \n#{exception.message}"
			redirect_to :back
		else
			flash[:error] = "An authentication error was encountered and you were logged out. Try again?"
			redirect_to '/'
		end
	end


	def home
	end

	def manage
		if not logged_in?
			flash[:error] = "Easy there! Log in first!"
			redirect_to '/'
		else
			if params[:id]
				@transaction = DwollaVars.Dwolla::Transactions.scheduled_by_id(params[:id], session[:oauth_token])

				@fs = []
				DwollaVars.Dwolla::FundingSources.get(nil, session[:oauth_token]).each do |h|
					@fs.push([h['Name'], h['Id']]) unless h['Name'] == "My Dwolla Balance"
				end

				render 'edit'
			else
				@scheduled = DwollaVars.Dwolla::Transactions.scheduled({}, session[:oauth_token])['Results']
				render 'manage'
			end
		end
	end

	def delete
		if not params[:delete]
			flash[:error] = "You've arrived here in error. Sorry!"
			redirect_to '/dashboard/manage'
		else
			DwollaVars.Dwolla::Transactions.delete_scheduled_by_id(params[:delete][:Id], {:pin => params[:delete][:pin]}, session[:oauth_token])
			flash[:success] = "You've successfully deleted the scheduled transaction"
			redirect_to '/dashboard/manage'
		end
	end

	# Session Management

	def direct
		redirect_to DwollaVars.Dwolla::OAuth.get_auth_url(DwollaVars.redirect)
	end

	def full
		redirect_to DwollaVars.Dwolla::OAuth.get_auth_url(DwollaVars.redirect, 'send|transactions|balance|request|contacts|accountinfofull|funding|scheduled', true)
	end

	def handle_oauth
		if not params['code'] 
			flash[:error] = "There was an issue logging in with Dwolla. Try again later."
			redirect_to "/"
		else
			# Set access token
			session[:oauth_token] = DwollaVars.Dwolla::OAuth.get_token(params['code'], DwollaVars.redirect)['access_token']

			# Set name, for aesthetics.
			session[:name] = DwollaVars.Dwolla::Users.me(session[:oauth_token])['Name']

			# Make user happy
			flash[:success] = "You have been successfully logged in!"
			redirect_to "/"
		end
	end

	def logout
		# Destroy the rails session hash
		reset_session
	    flash[:alert] = "You have logged out."
	    redirect_to "/"
	end
end
