{-# LANGUAGE OverloadedStrings #-}

import Web.Scotty (scotty, get, delete, post, json, jsonData,
    param, status, ScottyM, ActionM, finish, liftAndCatchIO, defaultHandler, rescue,
    notFound, text, html, redirect)
import Network.HTTP.Types (notFound404, internalServerError500, badRequest400, Status)
import qualified Data.Text.Lazy as TL (Text, unpack)
import Data.Aeson (object, (.=))
import Control.Monad (when)
import Data.Maybe (isNothing)
import Text.Read (readMaybe)

--Local imports
import Types (Bug(..), BugUpdate(..), TestStatus)
import Database (getBugs, updateBug, getBug, deleteBug, addBug)
import Templates

defaultDB :: String
defaultDB = "bugs.db"

main :: IO ()
main = scotty 3000 $ do
        defaultHandler (jsonError internalServerError500)
        routes defaultDB

--default error handler, return the message in json
jsonError :: Status -> TL.Text -> ActionM a
jsonError errorCode m = do
    status errorCode
    json $ object [ "errorMessage" .= m ]
    finish

textError :: Status -> TL.Text -> ActionM a
textError errorCode m = do
    status errorCode
    text m
    finish

routes :: String -> ScottyM ()
routes db = do
    get "/bugs" $ do
        bugs <- liftAndCatchIO (getBugs db)
                `rescue` textError internalServerError500
        html $ bugList bugs

    post "/bugs" $ do
        rawJiraId <- (param "jiraId" :: ActionM TL.Text)
            `rescue` textError badRequest400
        rawAssignment <- (param "assignment" :: ActionM TL.Text)
            `rescue` textError badRequest400
        rawTestStatus <- (param "testStatus" :: ActionM TL.Text)
            `rescue` textError badRequest400
        rawComments <- (param "comments" :: ActionM TL.Text)
            `rescue` textError badRequest400

        let maybeTestStatus = if rawTestStatus == "-"
                then Nothing
                else (readMaybe (TL.unpack rawTestStatus) :: Maybe TestStatus)
        when (rawTestStatus /= "-" && isNothing maybeTestStatus)
            $ textError badRequest400 "Invalid testStatus"

        let bugUpdate = BugUpdate
                            rawJiraId
                            (Just rawAssignment)
                            maybeTestStatus
                            (Just rawComments)
        numRowsChanged <- liftAndCatchIO (updateBug db bugUpdate)
                `rescue` textError internalServerError500

        when (numRowsChanged /= 1)
            $ textError internalServerError500 "Database error"
        redirect "/bugs"

    get "/api/bugs" $ do
        bugs <- liftAndCatchIO $ getBugs db
        json bugs

    get "/api/bugs/:bug" $ do
        bug <- (param "bug" :: ActionM TL.Text) `rescue` jsonError badRequest400
        r <- liftAndCatchIO $ getBug db bug
        case r of
            Just b -> json b
            _ -> status notFound404

    delete "/api/bugs/:bug" $ do
        bug <- (param "bug" :: ActionM TL.Text) `rescue` jsonError badRequest400
        numRowsChanged <- liftAndCatchIO $ deleteBug db bug
        when (numRowsChanged /= 1) (jsonError notFound404 "Failed to delete")
        finish

    post "/api/bugs" $ do
        request <- (jsonData :: ActionM Bug) `rescue` jsonError badRequest400
        numRowsChanged <- liftAndCatchIO $ addBug db request
        when (numRowsChanged /= 1) $ jsonError internalServerError500 "Database error"
        json request

    --default route, Scotty does a HTML based 404 by default
    notFound $ textError notFound404 "Not found"

