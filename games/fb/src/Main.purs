module Main where

import Effect (Effect)
import Effect.Class (class MonadEffect)
import Data.Int (toNumber)
import Node.Path as Path
import Node.Encoding (Encoding(..))
import Node.FS.Sync as S
import Effect.Timer as T
import Effect.Console (logShow)
--import Effect.Aff (Aff)
import Prelude
import Data.Maybe(Maybe(..), fromMaybe)
import Halogen as H
import DOM.HTML.Indexed.InputType (InputType(..)) as I
--import Halogen.Query.EventSource as ES
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Halogen.Aff (awaitBody, runHalogenAff)
import Halogen.VDom.Driver (runUI)
import Web.UIEvent.MouseEvent (MouseEvent, screenX, screenY)
import Data.Tuple (Tuple(..))
import Svg.Elements as SE
import Svg.Attributes as SA
import Data.Int (fromString)

type Position = Tuple Number Number

type State =
    { posViewBox :: Position
    , moveFromViewBox :: Maybe Position
    , moveFromScreen :: Maybe Position
    , sliderValue :: Int
    }

data Query a = Tick a
             | SliderChange String a
             | MoveThrough MouseEvent a
             | MoveStart   MouseEvent a
             | MoveEnd     MouseEvent a
             | GetState    (State -> a)

mouseEvent2Pos :: MouseEvent ->  Position
mouseEvent2Pos me = Tuple (toNumber $ screenX me) (toNumber $ screenY me)


component :: forall m. (MonadEffect m) => H.Component HH.HTML Query Unit Void m
component =
  H.component
    { initialState: const initialState
    , render
    , eval
    , receiver: const Nothing
    }
  where

  initialState :: State
  initialState =
               { posViewBox      : zero
               , moveFromViewBox : Nothing
               , moveFromScreen  : Nothing
               , sliderValue     : 3
               }

  render :: State -> H.ComponentHTML Query
  render state = 
    HH.div_
    [
        HH.label_
          [ HH.div_ [ HH.text $ "value:" <> show state.sliderValue]
          , HH.input
              [ HP.type_ I.InputRange
              , HP.min 1.0
              , HP.max 10.0
              , HP.value "3.0"
              -- , HP.class_ $ ClassName "slider"
              , HE.onValueInput (HE.input SliderChange)
              ]
          ]
    ,   SE.svg [SA.width w, SA.height h, SA.viewBox x y w h]
        [ SE.circle
          [ SA.r r
          , SA.fill $ Just (SA.RGB 0 0 100)
          , HE.onMouseDown (HE.input MoveStart)
          , HE.onMouseUp   (HE.input MoveEnd)
          , HE.onMouseLeave(HE.input MoveEnd)
          , HE.onMouseMove (HE.input MoveThrough)
          ]
        ]
    ]

    where
    h = 150.0
    w = 150.0
    r = w / 6.0
    Tuple x y = state.posViewBox - (Tuple (w / 2.0) (h / 2.0))

  eval :: (MonadEffect m) => Query ~> H.ComponentDSL State Query Void m
  eval = case _ of
          SliderChange v next -> do
            _ <- H.modify $ \state -> state { sliderValue = fromMaybe 0 $ fromString v }
            H.liftEffect $ logShow $ "!!!" <> v
            pure next
          Tick next -> do
            H.liftEffect $ logShow $ "tick"
            pure next
          MoveStart me next -> do
            _ <- H.modify $ \state -> state
                { moveFromViewBox = Just state.posViewBox
                , moveFromScreen = Just $ mouseEvent2Pos me
                }
            --H.liftEffect $ logShow $ "move start: " <> show (mouseEvent2Pos me)
            pure next
          MoveEnd me next -> do
            _ <- H.modify $ \state -> state
                { moveFromViewBox = Nothing
                , moveFromScreen = Nothing
                }
            --H.liftEffect $ logShow $ "move end"
            pure next
          MoveThrough me next -> do
            s <- H.get
            case s.moveFromScreen of
                Just offsetS -> do
                    --H.liftEffect $ logShow $ mouseEvent2Pos me
                    _ <- H.modify $ \state -> state
                        { posViewBox = fromMaybe state.posViewBox $ do
                            offsetVB <- state.moveFromViewBox
                            pure $ offsetVB - (mouseEvent2Pos me - offsetS)
                        }
                    --s' <- H.get
                    --H.liftEffect $ logShow $ s'.posViewBox
                    pure next
                Nothing -> do
                    pure next
          GetState reply -> do
            s <- H.get
            pure $ reply s



main :: Effect Unit
main = runHalogenAff do
  body <- awaitBody
  io <- runUI component unit body
  void $ H.liftEffect $ T.setInterval 2000 $ do
    runHalogenAff $ io.query $ H.action $ Tick
  void $ H.liftEffect $ T.setInterval 2000 $ do
    runHalogenAff $ do
        state <- io.query $ H.request $ GetState
        H.liftEffect $ S.appendTextFile ASCII (Path.concat [".", "hoge.txt"]) $ show state <> "\n"


